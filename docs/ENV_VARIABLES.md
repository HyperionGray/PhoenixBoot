# Environment Variables Configuration

This file documents the environment variables used by PhoenixBoot components.

## Production Flask Applications

### web/hardware_database_server.py

**CRITICAL**: This is a development/demo server. Do not deploy to production without proper configuration.

Required environment variables for production:

```bash
# Generate a secure secret key with:
# python -c 'import secrets; print(secrets.token_hex(32))'
export SECRET_KEY="your-secure-secret-key-here"

# Database path (optional, defaults to ./hardware_profiles.db)
export DB_PATH="/var/lib/phoenixguard/hardware_profiles.db"

# Upload directory (optional, defaults to ./hardware_uploads)
export UPLOADS_PATH="/var/lib/phoenixguard/uploads"
```

### ideas/cloud_integration/api_endpoints.py

**CRITICAL**: This is example/demo code. Do not use in production without security review.

Required environment variables for production:

```bash
# Flask secret key
export FLASK_SECRET_KEY="your-secure-secret-key-here"

# Redis configuration
export REDIS_HOST="localhost"
export REDIS_PORT="6379"
export REDIS_DB="1"
export REDIS_PASSWORD="your-redis-password"  # If Redis has authentication
```

## Task Runner (pf.py)

The pf.py task runner supports environment variables for configuration:

```bash
# Specify alternative Pfyfile location
export PFY_FILE="path/to/Pfyfile.pf"
```

## Build Environment

```bash
# EDK2 toolchain configuration
export EDK_TOOLS_PATH="/path/to/edk2/BaseTools"
export WORKSPACE="/path/to/edk2"

# Compiler selection
export GCC_VERSION="5"  # or appropriate version
```

## Secure Boot Keys

**WARNING**: Never commit private keys to version control!

```bash
# Directory containing Secure Boot keys
export SB_KEYS_DIR="/path/to/secure/keys"

# Individual key paths (optional)
export PK_KEY="/path/to/PK.key"
export PK_CRT="/path/to/PK.crt"
export KEK_KEY="/path/to/KEK.key"
export KEK_CRT="/path/to/KEK.crt"
export DB_KEY="/path/to/db.key"
export DB_CRT="/path/to/db.crt"
```

## Container Configuration

When running in containers, pass environment variables via docker-compose or command line:

```bash
# Using docker-compose
docker-compose --env-file .env up

# Using docker run
docker run -e SECRET_KEY="..." -e DB_PATH="..." phoenixboot/app
```

## Creating .env File

For development, create a `.env` file (DO NOT commit to git):

```bash
# .env file for local development
SECRET_KEY=dev-secret-key-change-in-production
FLASK_SECRET_KEY=dev-flask-key-change-in-production
DB_PATH=./local_dev.db
UPLOADS_PATH=./local_uploads
```

Then load it with:

```bash
# Bash
set -a
source .env
set +a

# Or use docker-compose
docker-compose --env-file .env up
```

## Security Best Practices

1. **Never commit `.env` files** - Add to `.gitignore`
2. **Use different secrets** for each environment (dev, staging, prod)
3. **Rotate secrets regularly** - Especially after team member changes
4. **Use strong secrets** - At least 32 characters of random data
5. **Restrict access** - Only give access to people who need it
6. **Use secret managers** - Consider using AWS Secrets Manager, HashiCorp Vault, etc. for production

## Verifying Configuration

To check if all required environment variables are set:

```bash
#!/bin/bash
# check_env.sh

required_vars=("SECRET_KEY" "FLASK_SECRET_KEY")

missing=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing+=("$var")
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required environment variables:"
    printf '  %s\n' "${missing[@]}"
    exit 1
fi

echo "✓ All required environment variables are set"
```

## Additional Resources

- [Twelve-Factor App: Config](https://12factor.net/config)
- [OWASP: Secure Configuration](https://owasp.org/www-project-secure-coding-practices/)
- [Python dotenv library](https://pypi.org/project/python-dotenv/)
