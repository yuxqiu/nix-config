# Inline/display math snippets and their keybindings (ctrl+m ctrl+m,
# ctrl+shift+m) for one VS Code language. `displayDelimiters` is the
# language's display-math { open; close; } pair. The leading underscore keeps
# import-tree from loading this file as a module.
{ languageId, displayDelimiters }:
let
  insertSnippet = key: name: {
    inherit key;
    command = "editor.action.insertSnippet";
    args = { inherit name; };
    when = "editorTextFocus && !editorReadonly && editorLangId == '${languageId}'";
  };
in
{
  keybindings = [
    (insertSnippet "ctrl+m ctrl+m" "Insert Inline Math")
    (insertSnippet "ctrl+shift+m" "Insert Display Math")
  ];

  languageSnippets.${languageId} = {
    "Insert Inline Math" = {
      prefix = "inlineMath";
      body = [ "\${1:$\${2:}$$0}" ];
      description = "Insert inline math block $$ $$ with easy backspace delete";
    };
    "Insert Display Math" = {
      prefix = "displayMath";
      body = [
        "\${1:${displayDelimiters.open}"
        "    \${2:}"
        "${displayDelimiters.close}}$0"
      ];
      description = "Insert 3-line display math block with cursor inside";
    };
  };
}
