---
name: maki-subsession
description: Use whenever the user says "maki-subsession", "subsession", "subsessions" or "sub-session". Delegates any sub-task (coding, review, research, writing, analysis, second opinion) to a separate maki session on a chosen provider/model, then reads back its result. Also use when a sub-task needs a model or provider the `task` subagent tool cannot select (it only takes a tier and stays on the current provider), a fully isolated context, or a different working directory.
---

# Subsession

A subsession is a fresh, non-interactive maki process started from `bash`.
It has its own model, its own context and full tools. It loads the project
instructions (`AGENTS.md` and similar) of the directory it starts in.

Use one when you need:
- a specific model or provider (`task` subagents cannot pick one);
- an independent opinion, with no influence from your context;
- work in another directory or repo;
- several model families on the same question, to compare their answers.

## Launch

```bash
cd <workdir> && maki -p --yolo -m <provider/model-id> --output-format json \
  [--max-turns N] [--disallowed-tools <tools>] \
  "<prompt>" > /tmp/subsession-<name>.json 2> /tmp/subsession-<name>.err
```

Keep stderr in a file: it holds the session id, which you need to resume a
run that died before writing its JSON.

- `-p`: non-interactive; runs the prompt and exits.
- `--yolo` is required. Without it, the first permission prompt blocks the run forever.
- `-m`: the model spec is `provider/model-id`. List the specs with `maki models`.
  If the user names a model loosely (`Provider:model`, a nickname), map it to the closest
  `maki models` entry. If none matches, stop and ask; never fall back to another model silently.
  Omit `-m` only when the user does not care about the model.
- Long prompts: pipe them on stdin (`maki -p ... < prompt.md`) instead of passing an argument.
- Read-only roles (review, research, opinion): add
  `--disallowed-tools write,edit,multiedit,edit_lines` and say "do not modify files"
  in the prompt. Also tell it whether it may run commands that have side effects.
- Long runs: make the `maki -p ...` line itself the bash tool's command, with
  `background: true` and a `timeout` (e.g. 5400). Then end your turn instead
  of polling. Never wrap it as `( maki ... ) &` or `nohup ... &`: the tool
  returns at once, you get no completion signal, and the detached process can
  die silently.
- Parallel subsessions that write files need separate workdirs (e.g. one git
  worktree each). Read-only ones can share a directory.

## Read the result

The JSON output looks like:
`{"type":"result","subtype":"success","is_error":false,"num_turns":..,"result":"<final text>","session_id":"..",...}`

```bash
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["is_error"], d["session_id"]); print(d["result"])' /tmp/subsession-<name>.json
```

- Check `is_error` and `subtype` before trusting `result`.
- An empty JSON file with no `maki -p` left in `ps` means the run died. Take
  the session id from the `.err` file and resume it (see below).
- A writer that died or returned an empty result may still have left edits:
  check `git status` in its workdir before relaunching.
- The result is a report, not proof. Check any claim that matters yourself
  (files changed, commands that passed, facts quoted).
- Tell the user the outcome in a line or two: the verdict (for a review, the
  finding count, or whether another round is needed) and the next step. Give
  details only when the user must decide something or asks for them.

## Follow up in the same subsession

```bash
cd <workdir> && maki -p --yolo -r <session_id> -m <same model> --output-format json "<follow-up>"
```

Use this to send findings back to the same worker, or to ask it a
clarifying question. It keeps its context, so the follow-up can be short.

## Writing the prompt

The subsession sees none of your conversation. Inline everything it needs:
- the goal, and the context needed to reach it (paths, the issue/task text or the command that fetches it, constraints);
- what it may and may not do (edit files? commit? push? network? side effects?);
- how to verify its work (the commands to run, and that it must check their exit codes);
- the exact final-answer format you will parse, e.g. a JSON shape, "numbered findings or exactly `NONE`", or a short summary with file:line refs.

## Limits

- `maki` has no CLI flag for reasoning effort. Unless effort is configured
  per model in maki's config, it cannot be changed per run. Tell the
  user when they ask for a specific effort.
- Cost and turns are only visible in the JSON afterwards. Use `--max-turns` to bound a run.
- A subsession cannot ask the user anything. Include the answers it would need up front, or tell it to stop and report the open questions.
