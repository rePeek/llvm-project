# LLVM 构建辅助
#
#   just configure               # 配置 build/release，并设为当前目录
#   just configure debug         # 配置 build/debug，并设为当前目录
#   just build clang lld         # 在当前目录里只构建指定 target（可多个）
#   just build-all               # 构建当前目录里的全部
#   just install                 # 把当前目录的产物装到 install/
#   just use debug               # 切到已配置好的 build/debug（不重跑 cmake）
#
# 设计：构建目录只跟构建模式走（build/release、build/debug），由 configure 决定，
# 并把选择记在 build/current 这个 symlink 里。所以 build/build-all 完全不需要知道 mode，
# 也不在构建时隐式跑 cmake；要换目录就 configure 或 use。
#
# 环境变量：MODE(默认 release) JOBS PROJECTS ARCHS LINK_JOBS PREFIX

# configure 的默认构建模式，只支持 release / debug
mode := env_var_or_default("MODE", "release")
# 并行编译任务数，默认等于 CPU 核数
jobs := env_var_or_default("JOBS", num_cpus() + "")
# 启用的 LLVM 子项目；只影响“能构建什么”，不影响只构建某几个 target 的开销
projects := env_var_or_default("PROJECTS", "clang;lld;lldb")
# 目标架构
archs := env_var_or_default("ARCHS", "X86;AArch64")
# 并行链接任务数：LLVM 链接非常吃内存
link_jobs := env_var_or_default("LINK_JOBS", "2")
# 安装前缀，默认 <仓库>/install（可用 PREFIX 覆盖）
prefix := env_var_or_default("PREFIX", justfile_directory() + "/install")

default:
    @just --list

# ─────────────────────────── 配置 ───────────────────────────

# 配置 build/{release,debug} 并设为当前目录；可重复执行，cmake 会增量重新配置
[group('setup')]
configure m=mode:
    @cmake -S llvm -B build/{{m}} -G Ninja \
      -DCMAKE_BUILD_TYPE={{m}} \
      -DCMAKE_INSTALL_PREFIX="{{prefix}}" \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DLLVM_ENABLE_PROJECTS="{{projects}}" \
      -DLLVM_TARGETS_TO_BUILD="{{archs}}" \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DLLVM_INCLUDE_TESTS=ON \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_INCLUDE_BENCHMARKS=OFF \
      -DLLVM_CCACHE_BUILD=ON \
      -DLLVM_USE_LINKER=lld \
      -DLLVM_PARALLEL_LINK_JOBS={{link_jobs}}
    @ln -sfn {{m}} build/current
    @echo "当前构建目录: build/{{m}}"

# 切换到已配置好的目录（只动 symlink，不重跑 cmake）；没配置过就先配置
[group('setup')]
use m:
    @[ -f build/{{m}}/build.ninja ] || just configure {{m}}
    @ln -sfn {{m}} build/current
    @echo "当前构建目录: build/{{m}}"

# build 只负责构建：目录必须已经由 configure 准备好
[private]
_configured:
    @[ -f build/current/build.ninja ] || { echo "还没有可用的构建目录，先运行：just configure [release|debug]" >&2; exit 1; }

# ─────────────────────────── 构建 ───────────────────────────

# 构建指定 target（至少一个，可多个）：just build clang lld
[group('build')]
build +targets:
    @just _configured
    @cmake --build build/current --parallel {{jobs}} --target {{targets}}

# 构建当前目录的全部（所有 llvm 工具 + clang / lld / lldb）
[group('build')]
build-all:
    @just _configured
    @cmake --build build/current --parallel {{jobs}}

# 安装到 configure 时的前缀（默认 install/，可用 PREFIX 覆盖）
[group('build')]
install:
    @just _configured
    @cmake --install build/current

# ─────────────────────────── 维护 ───────────────────────────

# 清掉当前目录的编译产物，保留 cmake 配置
[group('maintenance')]
clean:
    @just _configured
    @ninja -C build/current -t clean

# 删除整个 build/（所有模式的目录）
[group('maintenance')]
[confirm]
distclean:
    @rm -rf build && echo "已删除 build/"
