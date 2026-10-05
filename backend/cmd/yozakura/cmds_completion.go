package main

import (
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/brand"
)

// topCommands are completed after the binary name (keep in sync with showHelp).
var topCommands = []string{
	"config", "preset", "special", "cmd", "completion", "run", "toggle", "lock", "reload", "quit", "screen", "suspend",
	"brightness", "wallpaper", "schemes", "mods", "mcp", "voice", "ipc", "install", "remove",
	"colorpicker", "lockwall", "thumbs", "dthumbs", "update", "doctor", "refresh", "onboarding", "help", "version", "goodbye",
}

const (
	configSubs = "list get set toggle describe reset search schema path help"
	presetSubs = "list apply save update diff show aspects mix duplicate rename delete restore trash set-info export import try edit active help"
	keyedSubs  = "list get set toggle describe reset"
)

// Completion scripts complete config keys and values from the live catalog
// (`config __keys`, `config __values <key>`) and preset names
// (`preset __names`), so they never go stale.
const bashCompletion = `# bash completion for {bin} ({bin} completion bash)
_{bin}() {
    local cur=${COMP_WORDS[COMP_CWORD]} cmd=${COMP_WORDS[1]} sub=${COMP_WORDS[2]}
    local IFS=$'\n'
    if (( COMP_CWORD == 1 )); then
        COMPREPLY=($(IFS=' ' compgen -W "{top}" -- "$cur")); return
    fi
    case $cmd in
    config)
        if (( COMP_CWORD == 2 )); then COMPREPLY=($(IFS=' ' compgen -W "{configSubs}" -- "$cur")); return; fi
        case $sub in
        {keyedSubsBash})
            if (( COMP_CWORD == 3 )); then
                COMPREPLY=($(compgen -W "$({bin} config __keys 2>/dev/null)" -- "$cur"))
            elif [[ $sub == set ]] && (( COMP_CWORD == 4 )); then
                COMPREPLY=($(compgen -W "$({bin} config __values "${COMP_WORDS[3]}" 2>/dev/null)" -- "$cur"))
            fi ;;
        schema|path)
            (( COMP_CWORD == 3 )) && COMPREPLY=($(compgen -W "$({bin} config __domains 2>/dev/null)" -- "$cur")) ;;
        esac ;;
    preset)
        if (( COMP_CWORD == 2 )); then COMPREPLY=($(IFS=' ' compgen -W "{presetSubs}" -- "$cur")); return; fi
        case $sub in
        apply|diff|export|show|duplicate|rename|delete|update|try|edit|set-info)
            local names; names=$({bin} preset __names 2>/dev/null; echo current)
            COMPREPLY=($(compgen -W "$names" -- "$cur"))
            local i; for i in "${!COMPREPLY[@]}"; do COMPREPLY[i]=$(printf '%q' "${COMPREPLY[i]}"); done ;;
        import) COMPREPLY=($(compgen -f -- "$cur")) ;;
        esac ;;
    cmd)
        if (( COMP_CWORD == 2 )); then
            COMPREPLY=($(compgen -W "$({bin} cmd __ids 2>/dev/null; echo list)" -- "$cur"))
        else
            COMPREPLY=($(compgen -W "$({bin} cmd __args "$sub" 2>/dev/null)" -- "$cur"))
            local i; for i in "${!COMPREPLY[@]}"; do COMPREPLY[i]=$(printf '%q' "${COMPREPLY[i]}"); done
        fi ;;
    completion)
        (( COMP_CWORD == 2 )) && COMPREPLY=($(IFS=' ' compgen -W "bash zsh fish" -- "$cur")) ;;
    wallpaper|lockwall)
        COMPREPLY=($(compgen -f -- "$cur")) ;;
    esac
}
complete -F _{bin} {bin}
`

const zshCompletion = `#compdef {bin}
# zsh completion for {bin} ({bin} completion zsh)
_{bin}() {
    if (( CURRENT == 2 )); then compadd -- {top}; return; fi
    case $words[2] in
    config)
        if (( CURRENT == 3 )); then compadd -- {configSubs}; return; fi
        case $words[3] in
        {keyedSubsBash})
            if (( CURRENT == 4 )); then
                compadd -- ${(f)"$({bin} config __keys 2>/dev/null)"}
            elif [[ $words[3] == set ]] && (( CURRENT == 5 )); then
                compadd -- ${(f)"$({bin} config __values $words[4] 2>/dev/null)"}
            fi ;;
        schema|path) (( CURRENT == 4 )) && compadd -- ${(f)"$({bin} config __domains 2>/dev/null)"} ;;
        esac ;;
    preset)
        if (( CURRENT == 3 )); then compadd -- {presetSubs}; return; fi
        case $words[3] in
        apply|diff|export|show|duplicate|rename|delete|update|try|edit|set-info) compadd -- current ${(f)"$({bin} preset __names 2>/dev/null)"} ;;
        import) _files ;;
        esac ;;
    cmd)
        if (( CURRENT == 3 )); then compadd -- list ${(f)"$({bin} cmd __ids 2>/dev/null)"}
        else compadd -- ${(f)"$({bin} cmd __args $words[3] 2>/dev/null)"}; fi ;;
    completion) (( CURRENT == 3 )) && compadd -- bash zsh fish ;;
    wallpaper|lockwall) _files ;;
    esac
}
if [[ $zsh_eval_context[-1] == loadautofunc ]]; then
    _{bin} "$@"
else
    compdef _{bin} {bin}
fi
`

const fishCompletion = `# fish completion for {bin} ({bin} completion fish)
function __{bin}_args
    commandline -opc
end
function __{bin}_at --argument-names cmd sub pos
    set -l t (__{bin}_args)
    test (count $t) -eq $pos; or return 1
    test "$t[2]" = $cmd; or return 1
    test -z "$sub"; and return 0
    contains -- $t[3] (string split ' ' $sub)
end
function __{bin}_values
    set -l t (__{bin}_args)
    {bin} config __values $t[4] 2>/dev/null
end
complete -c {bin} -f
complete -c {bin} -n '__fish_use_subcommand' -a '{top}'
complete -c {bin} -n '__{bin}_at config "" 2' -a '{configSubs}'
complete -c {bin} -n '__{bin}_at config "{keyedSubs}" 3' -a '({bin} config __keys 2>/dev/null)'
complete -c {bin} -n '__{bin}_at config set 4' -a '(__{bin}_values)'
complete -c {bin} -n '__{bin}_at config "schema path" 3' -a '({bin} config __domains 2>/dev/null)'
complete -c {bin} -n '__{bin}_at preset "" 2' -a '{presetSubs}'
complete -c {bin} -n '__{bin}_at preset "apply diff export" 3' -a '(begin; {bin} preset __names 2>/dev/null; echo current; end)'
complete -c {bin} -n '__{bin}_at preset diff 4' -a '(begin; {bin} preset __names 2>/dev/null; echo current; end)'
complete -c {bin} -n '__{bin}_at preset import 3' -F
complete -c {bin} -n '__{bin}_at completion "" 2' -a 'bash zsh fish'
complete -c {bin} -n '__{bin}_at cmd "" 2' -a '(begin; {bin} cmd __ids 2>/dev/null; echo list; end)'
complete -c {bin} -n '__fish_seen_subcommand_from cmd; and test (count (__{bin}_args)) -eq 3' -a '({bin} cmd __args (__{bin}_args)[3] 2>/dev/null)'
complete -c {bin} -n '__fish_seen_subcommand_from wallpaper lockwall' -F
`

// completionScript renders the script for a shell.
func completionScript(shell string) (string, error) {
	var tpl string
	switch shell {
	case "bash":
		tpl = bashCompletion
	case "zsh":
		tpl = zshCompletion
	case "fish":
		tpl = fishCompletion
	default:
		return "", fmt.Errorf("unknown shell %q (bash, zsh or fish)", shell)
	}
	return strings.NewReplacer(
		"{bin}", brand.AppID,
		"{top}", strings.Join(topCommands, " "),
		"{configSubs}", configSubs,
		"{presetSubs}", presetSubs,
		"{keyedSubsBash}", strings.ReplaceAll(keyedSubs, " ", "|"),
		"{keyedSubs}", keyedSubs,
	).Replace(tpl), nil
}

// runCompletion implements `yozakura completion <bash|zsh|fish>`.
func runCompletion(args []string, out, errOut io.Writer) int {
	if len(args) != 1 {
		fmt.Fprintf(errOut, "Usage: %s completion <bash|zsh|fish>\n\n", brand.AppID)
		fmt.Fprintf(errOut, "  bash: %s completion bash > ~/.local/share/bash-completion/completions/%s\n", brand.AppID, brand.AppID)
		fmt.Fprintf(errOut, "  zsh:  %s completion zsh > \"${fpath[1]}/_%s\"\n", brand.AppID, brand.AppID)
		fmt.Fprintf(errOut, "  fish: %s completion fish > ~/.config/fish/completions/%s.fish\n", brand.AppID, brand.AppID)
		return 2
	}
	s, err := completionScript(args[0])
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 2
	}
	fmt.Fprint(out, s)
	return 0
}
