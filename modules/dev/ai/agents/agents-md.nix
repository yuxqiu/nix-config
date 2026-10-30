let
  agentsMd = ''
    ### Session Start

    Read in this exact order (skip any that don't exist):
    1. `README.md`
    2. `docs/HANDOFF.md`
    3. latest entry in `docs/SESSION_LOG.md`
    4. `docs/DECISIONS.md`
    5. `docs/RUNBOOK.md`

    ### During Work

    - Keep `docs/HANDOFF.md` aligned with current status and next actions. On multi-step tasks, update it after each completed sub-task so a cut-off session can resume.
    - Record durable decisions in `docs/DECISIONS.md`.
    - Keep operational command changes in `docs/RUNBOOK.md`.

    ### Session End

    - Update `docs/HANDOFF.md`:
      - `Last updated` timestamp (`YYYY-MM-DD HH:MM UTC`)
      - current state
      - top 3 next actions
      - blockers (if any)
    - Append a new timestamped entry to `docs/SESSION_LOG.md`.

    ### Operating Rules

    - If a tool is missing, get it with `nix shell nixpkgs#<pkg>` rather than working around it.
    - Prefer failing loudly (explicit errors, assertions, checks) over silent fallbacks or workarounds.
    - When the user rejects an approach, don't retry a variant of it; ask what direction they want.
    - When removing a feature or tool, remove it completely (packages, config, references, docs), not just disable it.

    ### Factual Accuracy

    - For non-obvious technical claims, check primary sources (papers, source code, release notes) before asserting. Cite where you checked; mark anything unverified as `[unverified]`.
    - When corrected, fix the wrong claim everywhere it appears (notes, slides, speaker notes, docs).

    ### Karpathy Guidelines

    Behavioral guidelines to reduce common LLM coding mistakes. These bias toward caution over speed. For trivial tasks, use judgment.

    #### 1. Think Before Coding

    Don't assume. Don't hide confusion. Surface tradeoffs.

    - State your assumptions explicitly. If uncertain, ask.
    - If multiple interpretations exist, present them — don't pick silently.
    - If a simpler approach exists, say so. Push back when warranted.
    - If something is unclear, stop. Name what's confusing. Ask.

    #### 2. Simplicity First

    Minimum code that solves the problem. Nothing speculative.

    - No features beyond what was asked.
    - No abstractions for single-use code.
    - No "flexibility" or "configurability" that wasn't requested.
    - No error handling for impossible scenarios.
    - If you write 200 lines and it could be 50, rewrite it.
    - Before introducing a new abstraction (schedules, hooks, extra interface fields, custom parsers), propose it in 2-3 sentences and wait for approval.
    - Use the standard library or well-established packages over hand-rolled equivalents (e.g. argument parsing, serialization).

    Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

    #### 3. Surgical Changes

    Touch only what you must. Clean up only your own mess.

    When editing existing code:

    - Don't "improve" adjacent code, comments, or formatting.
    - Don't refactor things that aren't broken.
    - Match existing style, even if you'd do it differently.
    - If you notice unrelated dead code, mention it — don't delete it.

    When your changes create orphans:

    - Remove imports/variables/functions that YOUR changes made unused.
    - Don't remove pre-existing dead code unless asked.

    The test: Every changed line should trace directly to the user's request.

    #### 4. Goal-Driven Execution

    Define success criteria. Loop until verified.

    Transform tasks into verifiable goals:

    - "Add validation" → "Write tests for invalid inputs, then make them pass"
    - "Fix the bug" → "Write a test that reproduces it, then make it pass"
    - "Refactor X" → "Ensure tests pass before and after"

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
