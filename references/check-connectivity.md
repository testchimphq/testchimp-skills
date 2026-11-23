# /testchimp check connectivity (retired — use `/testchimp connect-project`)

`/testchimp connect-project` replaced this command: linking the repo to a project **and** proving the connection are now one step, see [`connect-project.md`](./connect-project.md).

This stub stays so older setup guides (and TestChimp Studio, which still shows this command) keep working:

1. If the preamble shows a `TESTCHIMP_CREDS:` file, or this is a stdio / API-key setup whose project is fixed by its config, call **`get-eaas-config`** `{}` once (pass `projectId` from `creds.json` when hosted / plugin). Success means connected; then do the [hand-back](./onboarding-next-step.md).
2. If a hosted / plugin server is connected but there is no `creds.json`, follow [`connect-project.md`](./connect-project.md) instead.
3. Failures (401 / 403, network, tool missing) are handled in step 6 of `connect-project.md`.

Do **not** run project init or install anything here. Never answer "Next: run `/testchimp check connectivity`" right after it.
