"""
Run this once to generate a bcrypt hash for your admin login password, then
paste the output into ADMIN_PASSWORD_HASH in your .env file.

Usage:
    python make_admin_password.py "your-real-password"
"""
import sys

import bcrypt

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print('Usage: python make_admin_password.py "your-real-password"')
        sys.exit(1)
    print(bcrypt.hashpw(sys.argv[1].encode("utf-8"), bcrypt.gensalt()).decode("utf-8"))
