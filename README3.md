Wait, if you set the org.opencontainers.image.description label, does GHCR use that INSTEAD of the README, or does it display it alongside the README? It displays the description. The README is still pulled from the root of the repo (org.opencontainers.image.source).

If the user says: "we have a separate readme in tha tdirectory", maybe they are asking how to attach *that* README instead of the root README, or if the `org.opencontainers.image.description` label I added somehow attaches the README. My previous reply said: "GitHub Container Registry (GHCR) automatically links the image back to this repository and extracts its README.md to display on the package page."
I said "its README.md", which the user interpreted as "the README.md in that directory".
Actually, GHCR extracts the *root* README.md of the repository. It doesn't natively support subdirectory READMEs.

Wait! Is there an annotation like `org.opencontainers.image.documentation` or something?
Wait! If I pass the README file path? No, OCI image labels are just strings.
Wait, if I use `docker/build-push-action`, can we upload a README?
No, GitHub's container registry doesn't support uploading a README for an image separately via Docker CLI; it just pulls it from the repo.
But wait! What if I reply and say:
"Ah, apologies for the confusion! GitHub Container Registry (GHCR) currently only supports displaying the **root** `README.md` of the linked repository. It does not natively support pulling a README from a subdirectory just for the package page using OCI annotations alone.

The `org.opencontainers.image.description` label provides the short text description that appears under the package name on GHCR, but the full markdown README section below it will still be the main repo's `README.md`."
