---
name: kde-rootfs
description: Use when building or testing Arran's KDE Frameworks 6/Qt 6 desktop repositories (kjules, KMagMux, kgithub-notify, klookup) using their shared Debian rootfs and .jules wrapper scripts instead of Docker.
---
# KDE/Qt development in a shared rootfs

**Sources:** https://github.com/arran4/kde-dev-rootfs and the target project's AGENTS.md. This procedure applies to `kjules`, `KMagMux`, `kgithub-notify` and related Qt/KF projects that ship `.jules/bootstrap.sh` and `.jules/run.sh`.

## Build/test contract
1. Verify the target repo actually contains both scripts. Review them before running; this is a downloaded/chroot environment with nontrivial host privileges. Do not use the generic agent's Docker container as the build/test environment when the project's AGENTS.md specifically requires rootfs.
2. Use `.jules/bootstrap.sh` to provision the shared KDE development rootfs; avoid overwriting any existing container/session mounts.
3. Configure with `.jules/run.sh cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON` (adjust options to the repo's CMake configuration).
4. Build with `.jules/run.sh cmake --build build --parallel`; test with `.jules/run.sh ctest --test-dir build --output-on-failure`.
5. Use Qt 6 and KF6 APIs exclusively; never downgrade Qt or KDE to bypass compilation. Inspect moc, signal/slot, QObject lifetime, DBus and Wayland-specific errors against the target API/headers rather than guessing.
6. For UI tests requiring a display, record whether headless Xvfb/Wayland was actually provided; do not claim screenshot/UI behavior was tested based on compilation.
7. Put logs and repro artifacts in /tmp; capture exact compiler/KF6/Qt6 versions, build flags and failures; avoid full unrelated rootfs rebuilds.
8. Do not carry `.jules` branding into general documentation for agents unless it is the actual script interface; its name does not imply the Jules service is required.

## Completion
Provide configure/build/test commands and exit status, toolchain version and whether tests ran inside the required rootfs. Distinguish desktop-specific tests from CLI/headless unit tests.
