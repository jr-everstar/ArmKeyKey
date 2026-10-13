# Continuous integration

`.github/workflows/tests.yml` runs `Scripts/test.sh` on the GitHub-hosted
`macos-26` Apple Silicon runner. The job is named **Tests** so branch rules
can require a stable check name.

The workflow runs for pull requests targeting `main`, `release`, or
`release/**`, and for pushes to those branches. It also supports manual
runs from the Actions tab once the workflow is on the default branch.
There are no path filters: documentation-only pull requests also report
the required check. The workflow uses read-only repository permissions
and needs no repository secrets.

The existing suite checks imported inputs and notices, reproducible
dictionaries, engine behavior with sanitizers and legacy differential
traces, storage, character filtering, phrases, Jyutping, native controller
behavior, and installation paths. It does not install the input method or
publish a release. Native controller tests use AppKit and require a
graphical session; the first hosted run must confirm runner compatibility.
They do not replace the [manual cross-application release checks](Distribution.md#manual-release-acceptance).

## Enable required checks

1. Commit and push the workflow together with the project source to GitHub.
2. In **Actions → CI**, confirm that **Tests** completes successfully.
3. Open **Settings → Rules → Rulesets** and edit the active ruleset targeting
   `main` and the release branches.
4. Enable **Require status checks to pass**, add **Tests**, and choose
   **GitHub Actions** as its expected source. Save the ruleset.

Configure the required check after its first successful run. GitHub needs
a successful run from the past seven days to offer a workflow check for
selection. If enabling a merge queue later, add a `merge_group` trigger
before requiring this check for queued merges.
