cd "$(dirname "$0")"
ip link set lo up
python3 -I test_safe.py
