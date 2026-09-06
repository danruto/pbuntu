# pbuntu (fork of exeuntu)

You are running in an exe.dev VM using the pbuntu image (a personal fork of exeuntu).

<https://exe.dev/docs/proxy.md> has details about the exe.dev HTTPS proxy.

Only use documented exe.dev features (see <https://exe.dev/docs.md>). Undocumented local endpoints are internal infrastructure—unstable and unsupported.

## The project checkouts

This machine is shared by every project that needs its toolchains. Each project
keeps its checkout at `/home/exedev/<project>`; your working directory is the
checkout of the project you were started for, and the others are not yours to
touch. Every checkout is reached through exe.dev's git-auth proxy at
`github.int.exe.xyz`, using the integration attached to this machine — there is
no GitHub credential on the VM itself.

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

`git remote get-url origin` in the checkout names the repository to substitute.
