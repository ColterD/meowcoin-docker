# JWT Authentication

The Meowcoin Docker container supports JSON Web Token (JWT) authentication for secure RPC access.

## Enabling JWT Authentication

To enable JWT authentication, add the following to your `docker-compose.yml`:

```yaml
services:
  meowcoin:
    # ... other configuration ...
    environment:
      - ENABLE_JWT_AUTH=true
```

## How JWT Authentication Works

When enabled, the container will:

- Generate a secure JWT secret key  
- Configure the Meowcoin node to use JWT for authentication  
- Expose a RESTful API that uses JWT for authentication  

## Using JWT Authentication

To access the RPC API with JWT authentication:

```bash
# Get the JWT token
JWT_TOKEN=$(docker exec meowcoin-node cat /home/meowcoin/.meowcoin/.jwtsecret | xxd -p -c 1000)

# Use the token in API requests
curl -s -H "Authorization: Bearer $JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"method":"getblockchaininfo","params":[],"id":1}' \
     http://localhost:8332/
```

## Security Benefits

JWT authentication provides several advantages over traditional username/password authentication:

- Token-based authentication without sending credentials each time  
- Fine-grained access control possibilities  
- Better integration with modern API security patterns  
- Support for token expiration and renewal  

## Integration with External Services

JWT authentication makes it easier to integrate with:

- Modern web applications  
- Blockchain explorers  
- Monitoring dashboards  
- Third-party APIs  

## For Developers

For developers creating applications that interact with the Meowcoin node, JWT authentication provides a more secure and flexible authentication mechanism compatible with modern development frameworks.
