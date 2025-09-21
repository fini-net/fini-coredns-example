# Just Task Runner

This directory contains shared justfiles for project automation and workflow management.

## About Just

Just is a command runner written in Rust that provides a simple way to save and run project-specific commands. It's similar to Make but designed specifically for command running rather than building. Just recipes can include shell scripts, variables, and conditional execution.

### Installation

On macOS, install Just using Homebrew:

```bash
brew install just
```

For other platforms, see the [Just installation guide](https://just.systems/man/en/chapter_4.html).

## Available Recipes

Run `just` or `just --list` to see all available recipes. This repository includes:

### Process Management

- `branch <name>` - Start a new feature branch
- `pr` - Create pull request from current branch  
- `prweb` - View PR in web browser
- `merge` - Merge PR and return to main branch
- `sync` - Return to main branch and pull latest
- `release <version>` - Create a new GitHub release

### DNS Management

- `preview` - Preview DNS changes using DNSControl
- `push` - Generate BIND zone files from JavaScript configurations

### Container Operations

- `build_con` - Build container with Podman
- `run_con` - Run container locally (DNS server on port 1029)
- `test_quick` - Test containerized DNS server with dig
- `test_dns` - Run comprehensive Go tests against container
- `test_dns_race` - Run tests with race detection
- `test_dns_single <test>` - Run specific test
- `clean_con` - Stop and remove test container
- `inspect_con` - Inspect containerized CoreDNS
- `ghcr_login` - Login to GitHub Container Registry
- `ghcr_push` - Push container to GitHub Container Registry
- `ghcr_logout` - Logout from GitHub Container Registry

### Utilities

- `install_prereqs` - Install required tools via Homebrew (macOS)
- `debug` - Show internal justfile variables
- `utcdate` - Print UTC date in ISO format
- `list` - List all available recipes (default)

## File Structure

- `gh-process.just` - Shared GitHub workflow automation (imported by main justfile)
- Main `justfile` - Project-specific recipes for DNS and container management

## Usage Examples

```bash
# Start new feature branch
just branch dns-improvements

# Preview DNS changes before applying
just preview

# Build and test container
just build_con
just run_con
just test_quick
just clean_con

# Create PR and merge workflow
just pr
just merge
```

## Benefits of Just

- **Simple syntax** - Easy to read and write compared to Makefiles
- **Cross-platform** - Works consistently on macOS, Linux, and Windows
- **Shell integration** - Supports multiple shell types and scripting
- **Variable substitution** - Built-in support for variables and expressions
- **Error handling** - Better error reporting than traditional Make
- **No dependencies** - Single binary with no external dependencies
