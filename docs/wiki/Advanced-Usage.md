# Advanced Usage

## Multi-Node Setup

Run multiple Meowcoin nodes with different configurations:

```yaml
services:
  meowcoin-mainnet:
    image: colterd/meowcoin-docker:latest
    container_name: meowcoin-mainnet
    volumes:
      - meowcoin-mainnet:/home/meowcoin/.meowcoin
    ports:
      - "127.0.0.1:8332:8332"
      - "8333:8333"
      
  meowcoin-testnet:
    image: colterd/meowcoin-docker:latest
    container_name: meowcoin-testnet
    volumes:
      - meowcoin-testnet:/home/meowcoin/.meowcoin
    ports:
      - "127.0.0.1:18332:18332"
      - "18333:18333"
    environment:
      - CUSTOM_OPTS="testnet=1"

volumes:
  meowcoin-mainnet:
  meowcoin-testnet:
```

## Plugin System

The container supports plugins via a flexible extension mechanism:

```yaml
services:
  meowcoin:
    # Other settings...
    volumes:
      - meowcoin-data:/home/meowcoin/.meowcoin
      - ./plugins:/etc/meowcoin/plugins
    environment:
      - ENABLE_PLUGINS=true
```

### Creating Plugins

Plugins are shell scripts in the /etc/meowcoin/plugins directory:

```bash
#!/bin/bash
# plugins/example-plugin.sh

echo "Initializing example plugin"

# Add custom functionality
function custom_action() {
  echo "Executing custom action"
  # Do something useful
}

# Register plugin hooks
register_hook "startup" custom_action
```

### Available Plugin Hooks

- `startup`: Executed when the container starts  
- `shutdown`: Executed before container stops  
- `post_sync`: Executed when blockchain sync completes  
- `backup_pre`: Executed before backup creation  
- `backup_post`: Executed after backup creation  

## External Service Integration

### Integrating with Lightning Network

```yaml
services:
  meowcoin:
    # Meowcoin configuration...
    
  lightning:
    image: lightninglabs/lnd:latest
    container_name: lightning-node
    depends_on:
      - meowcoin
    volumes:
      - lightning-data:/root/.lnd
    ports:
      - "9735:9735"
      - "10009:10009"
    environment:
      - MEOWCOIN_RPC_HOST=meowcoin
      - MEOWCOIN_RPC_USER=${RPC_USER}
      - MEOWCOIN_RPC_PASSWORD=${RPC_PASSWORD}

volumes:
  meowcoin-data:
  lightning-data:
```

### Integrating with Block Explorer

```yaml
services:
  meowcoin:
    # Meowcoin configuration...
    
  explorer:
    image: blockexplorer/btc-rpc-explorer:latest
    container_name: meowcoin-explorer
    depends_on:
      - meowcoin
    ports:
      - "3002:3002"
    environment:
      - BTCEXP_HOST=0.0.0.0
      - BTCEXP_MEOWCOIN_RPC_HOST=meowcoin
      - BTCEXP_MEOWCOIN_RPC_PORT=8332
      - BTCEXP_MEOWCOIN_RPC_USER=${RPC_USER}
      - BTCEXP_MEOWCOIN_RPC_PASSWORD=${RPC_PASSWORD}
```

## Advanced Security Hardening

### SELinux Configuration

For systems with SELinux enabled:

```yaml
services:
  meowcoin:
    # Other settings...
    security_opt:
      - label:type:container_runtime_t
```

### AppArmor Profile

For systems with AppArmor:

```yaml
services:
  meowcoin:
    # Other settings...
    security_opt:
      - apparmor:meowcoin
```

Example AppArmor profile (`/etc/apparmor.d/docker-meowcoin`):

```text
#include <tunables/global>

profile docker-meowcoin flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  
  network,
  capability,
  file,
  umount,
  
  deny @{PROC}/{*,**^[0-9]*/} w,
  deny @{PROC}/sys/kernel/shmmax w,
  deny @{PROC}/sys/kernel/shmall w,
  deny @{PROC}/sys/kernel/shmmni w,
  
  # Allow access to blockchain data
  /home/meowcoin/.meowcoin/** rwk,
  
  # Restrict system access
  deny /bin/** wl,
  deny /sbin/** wl,
  deny /usr/bin/** wl,
  deny /usr/sbin/** wl,
}
```
