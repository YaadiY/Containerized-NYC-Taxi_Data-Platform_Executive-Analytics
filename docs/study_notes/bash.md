# Bash Study Notes (Git Bash on Windows)

Bash is a command-line shell. It expands paths and variables, connects commands with pipes, and returns exit codes. This repository recommends Git Bash for shell examples; PowerShell has different syntax.

## Daily Commands

    pwd
    ls
    cd /c/Users/yeleg/VS/postgres_docker
    rg --files
    rg -n "CREATE TABLE" sql
    docker compose ps

## Quoting and Paths

- Single quotes keep shell metacharacters literal; double quotes allow variable expansion.
- Quote paths containing spaces.
- Git Bash paths commonly use /c/Users/...; PowerShell uses C:\Users\....
- * and ? are globs. A quoted glob is literal unless the program expands it.

## Variables, Pipes, and Exit Codes

    table_name='yellow_taxi_trips_2025_01'
    printf '%s\n' "$table_name"
    rg -n 'payment_type' sql | head -20
    echo "$?"

The pipe sends stdout from one process to stdin of another. && runs the next command only after success. $? is the previous command's exit code: zero means success, nonzero means failure. Do not assume a pipeline's final command proves every earlier command succeeded unless pipefail is enabled.

For scripts, learn set -euo pipefail, functions, for loops, case, and trap-based cleanup. Understand each option before adding it to a pipeline script.

## Interview Questions

1. What is a pipe? It connects stdout from one process to stdin of another.
2. Why quote variables? To prevent word splitting and glob expansion from changing a path or value.
3. What does an exit code tell you? Whether a process reported success (0) or failure (nonzero).
4. How is Bash different from PowerShell? They are different shells with different syntax, paths, and command semantics.
