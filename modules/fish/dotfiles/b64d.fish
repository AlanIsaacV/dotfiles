function b64d --description "Decodifica base64 desde argumento o clipboard"
    set -l content ""
    if count $argv > /dev/null
        set content $argv
    else
        if type -q pbpaste
            set content (pbpaste)
        else if type -q wl-paste
            set content (wl-paste)
        else if type -q xclip
            set content (xclip -selection clipboard -o)
        else
            echo "⚠️  Modo SSH/Servidor: No se detectó portapapeles local."
            echo "Uso: b64d 'texto_en_base64'"
            return 1
        end
    end

    if base64 --version 2>&1 | grep -q "GNU"
        # Linux (GNU) suele usar -d
        echo -n "$content" | base64 -d
    else
        # macOS (BSD) suele usar -D
        echo -n "$content" | base64 -D
    end

    echo "" # Salto de línea final
end
