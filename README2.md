Wait, if there is no way to do this via labels, maybe the user expects `docker/metadata-action` to handle it? No, `docker/metadata-action` does not have a "readme" option. Wait, it doesn't.
Wait, let me double check the OCI annotations.
`org.opencontainers.image.documentation` or `org.opencontainers.image.url` or `org.opencontainers.image.source`.
Is there a GitHub-specific annotation? No, usually not.

Wait, if they want to attach the new README specifically for this, maybe they are asking how it works, and they are pointing out there is a separate README in that directory. I can just explain that GHCR only supports the repository root README automatically, or I can tell them that the only way to do it is if we manually publish the package using an API or if GHCR recently added a feature.
Actually, let me check `org.opencontainers.image.source`. If we set `org.opencontainers.image.source` to the github repo URL, GHCR links the package to the repo and uses the root README.
However, I found out that we can use `org.opencontainers.image.documentation`?
Let me check the OCI specs for `org.opencontainers.image.documentation`:
"URL to get documentation for the image."

Let me search for "ghcr.io readme from subdirectory".
