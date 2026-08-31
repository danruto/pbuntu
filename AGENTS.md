# pbuntu (fork of exeuntu)

You are running in an exe.dev VM using the pbuntu image (a personal fork of exeuntu).

The image can ship host metrics to an OpenObserve instance when the
provisioning layer has written `/exe.dev/obs.env` (endpoint, org, login user,
optional stream) and `/exe.dev/obs.secret` (the login password). `obs-enroll.service`
probes the endpoint and, when it answers and accepts the credentials, downloads
the OpenTelemetry Collector into the user prefix and starts it; without those
files it stays inert.

<https://exe.dev/docs/proxy.md> has details about the exe.dev HTTPS proxy.

Only use documented exe.dev features (see <https://exe.dev/docs.md>). Undocumented local endpoints are internal infrastructure—unstable and unsupported.

## The project checkout

Every VM keeps its checkout at `/home/exedev/project`. It is reached through
exe.dev's git-auth proxy at `github.int.exe.xyz`, using the integration attached
to this machine — there is no GitHub credential on the VM itself.

If `git -C /home/exedev/project status` reports a detached HEAD, this is a shared
pool machine and the checkout is a ref store, not a workspace. Cut a worktree or
a branch and work there. A commit made on the detached HEAD belongs to no branch
and is not reachable after the next refresh.

## Pushing and opening pull requests

This machine's access to the repository is time-boxed and lapses without
warning, so an unpushed commit is a lost commit. Push as soon as you have
something worth keeping, and keep pushing:

    git push -u origin <branch>

Open pull requests through the REST API. The proxy accepts only
single-repository REST calls and answers anything else with 403, so `gh pr
create` does not work here:

    GH_HOST=github.int.exe.xyz gh api --method POST repos/<owner>/<repo>/pulls \
      -f title="one line naming what changed" \
      -f head=<branch> \
      -f base=<default-branch> \
      -f body="what changed and why, for a reviewer"

`git -C /home/exedev/project remote get-url origin` names the repository to
substitute.
