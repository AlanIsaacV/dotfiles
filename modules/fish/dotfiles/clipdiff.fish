function clipdiff --description "Compara el contenido del portapapeles con un archivo"
    if test (count $argv) -eq 0
        echo "⚠️  Uso: clipdiff <archivo>"
        echo "Compara el contenido del portapapeles con el archivo especificado"
        return 1
    end

    set -l target_file $argv[1]

    if not test -f "$target_file"
        echo "⚠️  El archivo '$target_file' no existe"
        return 1
    end

    if type -q kitten; and test "$TERM" = "xterm-kitty"
        if type -q pbpaste
            kitten diff "$target_file" (pbpaste | psub)
        else if type -q wl-paste
            kitten diff "$target_file" (wl-paste | psub)
        else if type -q xclip
            kitten diff "$target_file" (xclip -selection clipboard -o | psub)
        else
            echo "⚠️  Modo SSH/Servidor: No se detectó portapapeles local."
            return 1
        end
    else
        if type -q pbpaste
            pbpaste | diff -y --suppress-common-lines "$target_file" -
        else if type -q wl-paste
            wl-paste | diff -y --suppress-common-lines "$target_file" -
        else if type -q xclip
            xclip -selection clipboard -o | diff -y --suppress-common-lines "$target_file" -
        else
            echo "⚠️  Modo SSH/Servidor: No se detectó portapapeles local."
            return 1
        end
    end
end
