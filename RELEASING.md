# Releases

Normal pushes run checks without publishing to CurseForge. Pushing a tag starting with `v` runs the release workflow, tests the addon, and uploads the package.

## One-time setup

In GitHub Settings â†’ Secrets and variables â†’ Actions:

The CurseForge project ID **1756454** is already set in both TOC files.
- Add a repository secret named `CF_API_TOKEN` with an upload token from your CurseForge author account. Never commit the token.

This uses BigWigsMods/packager. Leave CurseForge's separate automatic packaging integration disabled to avoid duplicate uploads.

## Publish a tested version

1. Test both supported clients in game. The Python checks use a WoW API test double and cannot verify actual rendering or delivery.
2. Update `## Version` in both TOC files and update CHANGELOG.md. Use a beta suffix for test builds, such as `0.15.1-beta1`.
3. Commit and push; check that the Check addon workflow succeeds.
4. Create and push a matching annotated tag, for example `git tag -a v0.15.1-beta1 -m "0.15.1 beta 1"` and `git push origin v0.15.1-beta1`.
5. Check the Release addon workflow and the uploaded file's game versions and release type on CurseForge. Moderation may still be required.

The tag must match both TOC versions. Release configuration is checked before any upload. No release tag was created as part of the initial repository setup.

Documentation: https://github.com/BigWigsMods/packager
