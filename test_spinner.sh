printf "Compiling Caelestia installer"
{
    while true; do
        printf "."
        sleep 0.5
        printf "."
        sleep 0.5
        printf "."
        sleep 0.5
        printf "\b\b\b   \b\b\b"
    done
} &
SPINNER_PID=$!
sleep 3
kill $SPINNER_PID 2>/dev/null
wait $SPINNER_PID 2>/dev/null || true
echo " Done!"
