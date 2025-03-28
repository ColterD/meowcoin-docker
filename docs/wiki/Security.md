# Security Best Practices

## Default Security Features

The Meowcoin Docker image includes several security features:

1. **Non-root Execution**: Container runs as non-privileged user  
2. **Auto-generated Credentials**: Secure RPC credentials generated automatically  
3. **Local-only RPC**: RPC interface bound to localhost by default  
4. **Secure Defaults**: Safe configuration with minimal attack surface  

## Enhanced Security Options

### SSL/TLS Encryption

Enable SSL for RPC communications:

```yaml
environment:
  - ENABLE_SSL=true
```

This generates self-signed certificates automatically. For production use, consider mounting your own certificates:

```yaml
volumes:
  - ./certs/meowcoin.crt:/home/meowcoin/.meowcoin/certs/meowcoin.crt:ro
  - ./certs/meowcoin.key:/home/meowcoin/.meowcoin/certs/meowcoin.key:ro
```

### Fail2ban Protection

Enable fail2ban to protect against brute force attacks:

```yaml
environment:
  - ENABLE_FAIL2BAN=true
```

Fail2ban will monitor RPC authentication failures and temporarily block IPs after multiple failed attempts.

### JWT Authentication

For modern authentication with APIs:

```yaml
environment:
  - ENABLE_JWT_AUTH=true
```

### Read-only Filesystem

Enable read-only filesystem for enhanced security:

```yaml
environment:
  - ENABLE_READONLY_FS=true
```

This makes the filesystem read-only except for necessary data directories.

## Network Security

### Firewall Configuration

Only expose necessary ports:

```yaml
ports:
  - "127.0.0.1:8332:8332"  # RPC only on localhost
  - "8333:8333"            # P2P port open
```

For additional security, use a host firewall to restrict P2P connections to trusted IPs.

### Reverse Proxy

For secure remote access, use a reverse proxy with TLS:

- Set up Nginx with Let's Encrypt certificates  
- Configure proxy to RPC port  
- Add strong authentication (basic auth, IP restrictions)  

Example Nginx configuration:

```nginx
server {
    listen 443 ssl;
    server_name meowcoin.example.com;
    
    ssl_certificate /etc/letsencrypt/live/meowcoin.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/meowcoin.example.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:8332;
        auth_basic "Restricted";
        auth_basic_user_file /etc/nginx/.htpasswd;
        allow 192.168.1.0/24;
        deny all;
    }
}
```

## Container Hardening

### Resource Limits

Prevent resource exhaustion with limits:

```yaml
deploy:
  resources:
    limits:
      memory: 4G
      cpus: '2'
```

### Seccomp Profiles

Add a custom seccomp profile:

```yaml
security_opt:
  - seccomp:/path/to/seccomp-profile.json
```

### Read-only Root Filesystem

Enable read-only root filesystem:

```yaml
read_only: true
tmpfs:
  - /tmp
  - /var/run
```

## Regular Security Maintenance

- Keep the container image updated  
- Check for security advisories  
- Rotate credentials regularly  
- Monitor logs for suspicious activity  
