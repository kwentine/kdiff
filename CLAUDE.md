# Table of Contents

1.  [Problem statement](#orgbc98a32)
    1.  [Ideas for improvements](#org8fbd7ab)
    2.  [Examples](#org6bab385)
    3.  [Design considerations](#orgd002128)
2.  [Brainstorming instructions](#org9835350)
3.  [Agent context](#orgaabc427)


# Problem statement

The goal of this project is to enhance the `argocd diff` and `kubectl diff` user experience.


## Ideas for improvements

-   Control over what is diffed
    -   Limit the diff to a given `.kind` of resources, for example `Pod`
    -   Limit the scope of the diff, for example to the resource `.spec`
    -   Remove noisy fields from the diff, such as `last-applied-configuration`
    -   More generally, allow arbitrary `yq` preprocessing of manifests before the diff
-   Ability to still choose custom diff tool
    -   use any of `dyff`, `difftastic`, `delta` etc&#x2026;


## Examples

    # Assume the script is called kdiff
    # Should output a helpful message
    kdiff --help

    # Diff only the resource specs
    # Use kubectl diff as default command, and forward all arguments after --
    kdiff --scope=.spec -- -rR overlays/staging

    # Show the diff for services and pods
    kdiff --kind=svc,po -- argocd diff myapp

    # Use kdiff with a predefined set of arguments as KUBECTL_EXTERNAL_DIFF
    # kdiff should know wether it is invoked interactively, or as KUBECTL_EXTERNAL_DIFF
    export KUBECTL_EXTERNAL_DIFF="kdiff --yq '... style=\"\" | del(.metadata.labels)'"
    kubectl diff -f mypod.yaml

    # The user should be able to use any diff tool
    KUBECTL_EXTERNAL_DIFF=fancydiff
    kdiff --ignore=.metadata.labels,.spec.affinity -- -f mydeploy.yaml

## Design considerations

-   Diff generation
    -   Hooking into `KUBECTL_EXTERNAL_DIFF` seems a good idea
    -   It should be possible to call the script interactively,
        or assign it directly to `KUBECTL_EXTERNAL_DIFF`
    -   If called interactively,
        the users original `KUBECTL_EXTERNAL_DIFF` should be taken into consideration
    -   Bash could be a suitable programming language for this part,
        but I am open to suggestions
-   The script name should be short, elegant and convey the ideas of flexibility, kubernetes, and diffing.


# Context

-   You can find an initial design plan in `PLAN.md`
-   You should create a `TODO.md` file that will hold finer-grained task descriptions and concrete next steps.
-   You should regularly commit your changes to the branch `claude/main` (current branch)
