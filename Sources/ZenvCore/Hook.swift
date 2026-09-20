public enum Hook {
    public static let startMarker = "# --- zenv safe display start ---"
    public static let endMarker = "# --- zenv safe display end ---"

    public static var content: String {
        """
        \(startMarker)
        _zenv_load() {
            local _exports _keys
            _exports="$(command zenv env 2>/dev/null)" || _exports=""
            eval "$_exports"
            _keys="$(command zenv keys 2>/dev/null | tr '\\n' '|' | sed 's/|$//')"
            export _ZENV_KEYS="$_keys"
        }
        _zenv_load
        unset -f _zenv_load

        _zenv_masker() {
            if [ -n "$_ZENV_KEYS" ]; then
                sed -E "/^($_ZENV_KEYS)=/s/=.*/=********/"
            else
                cat
            fi
        }

        env() { command env "$@" | _zenv_masker; }
        printenv() {
            if [ "$#" -eq 0 ]; then
                command printenv | _zenv_masker
                return
            fi
            if [ -n "$_ZENV_KEYS" ] && printf '|%s|' "$_ZENV_KEYS" | grep -q "|${1}|"; then
                echo "********"
                return
            fi
            command printenv "$@"
        }
        \(endMarker)
        """
    }

    public static func isInstalled(in text: String) -> Bool {
        text.contains(startMarker)
    }

    public static func install(into text: String) -> String {
        if isInstalled(in: text) {
            return text
        }
        var next = text
        if !next.hasSuffix("\n") {
            next += "\n"
        }
        return next + "\n" + content + "\n"
    }
}
