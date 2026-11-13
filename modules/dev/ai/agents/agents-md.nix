let
  agentsMd = ''
    The project's AGENTS.md and the user's instructions take precedence over this file where they conflict.

    ## Session Start

    Read in this exact order (skip any that don't exist):
    1. `README.md`
    2. `docs/HANDOFF.md`
    3. latest entry in `docs/SESSION_LOG.md`
    4. `docs/DECISIONS.md`
    5. `docs/RUNBOOK.md`

    ## During Work

    - Keep `docs/HANDOFF.md` aligned with current status and next actions. On multi-step tasks, update it after each completed sub-task so a cut-off session can resume.
    - Record durable decisions in `docs/DECISIONS.md`: what, why, the evidence and the rejected alternatives. When a decision changes, the new entry names the one it replaces. Design and spec docs describe only the current system.
    - Keep operational command changes in `docs/RUNBOOK.md`.

    ## Session End

    - Update `docs/HANDOFF.md`:
      - `Last updated` timestamp (`YYYY-MM-DD HH:MM UTC`)
      - current state
      - top 3 next actions
      - blockers (if any)
    - Append a new timestamped entry to `docs/SESSION_LOG.md`.

    ## Operating Rules

    - If a tool is missing, get it with `nix shell nixpkgs#<pkg>` rather than working around it.
    - Prefer failing loudly (explicit errors, assertions, checks) over silent fallbacks or workarounds.
    - When the user rejects an approach, don't retry a variant of it; ask what direction they want.
    - When removing a feature or tool, remove it completely (packages, config, references, docs), not just disable it.

    ## Factual Accuracy

    - For non-obvious technical claims, check primary sources (papers, source code, release notes) before asserting. Cite where you checked; mark anything unverified as `[unverified]`.
    - When corrected, fix the wrong claim everywhere it appears (notes, slides, speaker notes, docs).

    ## Code

    - Comments describe the current code: what it does and, when useful, why. No history ("it used to…", old values, before/after results); that goes in `docs/DECISIONS.md` or the commit message.
    - Write names and comments a reader understands without the conversation. Names say what a thing is in the domain; avoid vague ones (`Data`, `Info`, `Manager`, `Handled`).
    - Make illegal states unrepresentable: fields valid only together, or that exclude each other, go into one type.
    - Keep decisions in plain code without I/O (inputs in, results or actions out) and keep the I/O layer thin, so the decisions can be tested directly.
    - Each rule lives in one place that every caller uses. When the same bug appears at several call sites, give the rule one home instead of patching each.
    - Prefer one consistent rule over special cases and exemptions.
    - Every constant has a known source (a spec, a measurement, a documented limit), stated next to it. A value found by trial and error (a sleep, padding, a loose tolerance) means the mechanism isn't understood yet: find it instead of tuning the number.
    - Don't add migration or backward-compatibility code unless the user confirms that existing data or users depend on the old behaviour.

    ## Tests

    - Test each unit through its interface (inputs, outputs, effects), not its private details, so tests survive refactors.
    - Scratch and test git repos set `commit.gpgsign false` and `core.hooksPath /dev/null` locally; global commit signing otherwise stalls them on a prompt. Tell subagents the same.

    ## Working With the User

    - Anything the user must read or do (instructions, a question) goes in the final message of the turn; text between tool calls may not be seen.
    - Ask before actions the user would notice outside the repo (sound, stopping services, using devices or accounts), and restore what you changed.
    - Run commands that can block (concurrency tests, network, devices) with a timeout or in the background.
    - Check reviewer and subagent findings in the code before acting on them, and tell the user what you checked. If a finding would undo a decision in `docs/DECISIONS.md`, cite it and let the user decide whether things have changed; don't apply or drop it silently.
    - Scripts that produce evidence check their own results and exit non-zero on failure; don't leave the check to the reader.

    ## Publishing

    - Before publishing data or logs (including test data), scan them for identifiers (addresses, serial numbers, names, timestamps) and drop what isn't needed. Use made-up identifiers in examples and tests.
    - Public repos hold no private material (personal data, private project names, local paths); examples are neutral. Tracked agent files (skills, AGENTS.md) are public too.
    - Release notes describe what users notice, not how it was implemented.

    ## Karpathy Guidelines

    Behavioral guidelines to reduce common LLM coding mistakes. These bias toward caution over speed. For trivial tasks, use judgment.

    ### 1. Think Before Coding

    Don't assume. Don't hide confusion. Surface tradeoffs.

    - State your assumptions explicitly. If uncertain, ask.
    - If multiple interpretations exist, present them — don't pick silently.
    - If a simpler approach exists, say so. Push back when warranted.
    - If something is unclear, stop. Name what's confusing. Ask.

    ### 2. Simplicity First

    Minimum code that solves the problem. Nothing speculative.

    - No features beyond what was asked.
    - No abstractions for single-use code.
    - No "flexibility" or "configurability" that wasn't requested: a field, option or setting exists only if something reads it.
    - No error handling for impossible scenarios, or for inputs that can be built but never occur in practice. Ask where an input would come from before handling it.
    - If you write 200 lines and it could be 50, rewrite it.
    - Before introducing a new abstraction (schedules, hooks, extra interface fields, custom parsers), propose it in 2-3 sentences and wait for approval.
    - Use the standard library or well-established packages over hand-rolled equivalents (e.g. argument parsing, serialization).

    Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

    ### 3. Surgical Changes

    Keep each change focused on the task, so its diff is easy to review.

    When editing existing code:

    - Don't restyle or reformat adjacent code, and match the existing style.
    - A refactor beyond the task is welcome when it pays off: the fix gets simpler, a rule gets one home, a class of bug goes away. Propose it in a sentence or two with that benefit, and do it once the user agrees. In a codebase the user doesn't own, keep to the task unless asked.
    - If you notice unrelated dead code, mention it — don't delete it.

    When your changes create orphans:

    - Remove imports/variables/functions that YOUR changes made unused.
    - Don't remove pre-existing dead code unless asked.

    The test: every changed line traces to the user's request or to a refactor they approved.

    ### 4. Goal-Driven Execution

    Define success criteria. Loop until verified.

    Transform tasks into verifiable goals:

    - "Add validation" → "Write tests for invalid inputs, then make them pass"
    - "Fix the bug" → "Write a test that reproduces it, check that it fails without the fix, then make it pass"
    - "Refactor X" → "Ensure the tests pass before and after, unchanged (a test that must change means the behaviour changed: say so)"

    For multi-step tasks, state a brief plan:

    1. [Step] → verify: [check]
    2. [Step] → verify: [check]
    3. [Step] → verify: [check]

    Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
  '';
in
{
  flake.modules.homeManager.agents-md =
    { lib, config, ... }:
    {
      options.my.agents-md.destinations = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Map of agent names to their AGENTS.md destination paths relative to $HOME.";
      };

      options.my.agents-md.content = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "The shared AGENTS.md content, for agents that ingest it via a non-AGENTS.md path (e.g. Claude Code's CLAUDE.md).";
      };

      config.my.agents-md.content = agentsMd;

      config.home.file = lib.mapAttrs' (name: path: {
        name = path;
        value.text = agentsMd;
      }) config.my.agents-md.destinations;
    };
}
