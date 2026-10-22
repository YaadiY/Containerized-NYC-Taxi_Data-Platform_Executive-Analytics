# Git & GitHub for Data Engineering

This guide covers core Git workflows, team branching strategies, CI/CD fundamentals, and production repository hygiene required for Data Engineering interviews and day-to-day operations.

---

## 1. What Git & GitHub Solve in Data Teams

| Problem Without Git | How Git & GitHub Fix It |
| :--- | :--- |
| Untracked pipeline changes breaking downstream DAGs | Commit history provides auditability, lineage, and exact points of failure. |
| Ingestion scripts hardcoded with credentials/data files | `.gitignore` ensures secrets and multi-gigabyte Parquet/CSV dumps stay out of the repo. |
| Multiple engineers editing SQL models or DBT code simultaneously | Branching, pull requests, and automated testing prevent clobbering production tables. |
| Manual script execution across environments | GitHub Actions CI/CD automates linting, testing, and Docker image builds. |

---

## 2. Practical Workflows Used in This Project

### A. Protecting Secrets & Large Data via `.gitignore`
In our NYC taxi pipeline, we strictly avoid pushing binary data files and database storage:
```gitignore
# Exclude raw dataset downloads and database persistence volumes
nyc_taxi_data/
pg_data/
*.parquet
*.csv
.env
__pycache__/
.venv/
```
> **Interview Question:** *"Why shouldn't you commit Parquet files or database volumes into Git?"*
> **Answer:** Git uses snapshot deltas designed for text files. Committing multi-gigabyte Parquet/CSV files inflates repository clone size permanently, slows down CI/CD runners, and risks leaking sensitive PII or business data into version control. Large artifacts belong in object storage (S3, GCS) or data lakes, tracked via metadata/pointers.

---

### B. Core Daily Commands & What They Actually Do

| Command | Deep Technical Explanation |
| :--- | :--- |
| `git status` | Compares the Working Directory against the Index (staging) and HEAD commit. |
| `git diff` | Shows line-by-line chunk modifications not yet staged. |
| `git add <file>` | Computes SHA-1/SHA-256 hash of file content, writes a blob object to `.git/objects`, and updates the index file. |
| `git commit -m "msg"` | Creates a commit object linking a tree snapshot (directory state) to the parent commit SHA. |
| `git pull --rebase origin main` | Fetches remote commits and replays local commits on top of the latest upstream branch, avoiding messy merge commits. |
| `git push origin <branch>` | Updates remote branch ref pointers to point to your latest commit SHAs. |

---

## 3. Team Branching Strategies & Gitflow

### GitHub Flow (Industry Standard for DE & Analytics Engineering)
1. **`main`**: Always deployable, representing production pipeline code (e.g., orchestrators, dbt models, ingestion scripts).
2. **Feature Branches (`feat/ingest-2025`, `fix/flex-fare-filter`)**: Created off `main` for isolated feature development or bugfixes.
3. **Pull Request (PR)**:
   - Triggers automated CI tests (SQL linter `sqlfluff`, Python tests `pytest`, Docker image validation).
   - Requires peer code review before approval.
4. **Merge & Deploy**: Squash-merged into `main` and triggered via CI/CD to production environments.

---

## 4. Resolving Merge Conflicts in SQL & Python Scripts

### Why Conflicts Happen
When two branches modify the same lines or nearby blocks in a file (e.g., both branches modify `ingest.py` arguments or `gold_yellow_taxi_daily_demand.sql` grouping clauses).

### Step-by-Step Resolution
```bash
# 1. Fetch latest changes from main
git checkout feat/ingest-update
git fetch origin
git rebase origin/main

# 2. Git stops at the conflict:
# <<<<<<< HEAD (remote changes)
# =======
# >>>>>>> feat/ingest-update (your local changes)

# 3. Manually edit the file to keep the correct logic, then:
git add ingest.py
git rebase --continue

# 4. Push updated feature branch (force with lease prevents overwriting colleague work)
git push origin feat/ingest-update --force-with-lease
```

---

## 5. GitHub Actions & CI/CD for Data Pipelines

A typical Data Engineering Pull Request workflow executes:
1. **Linting & Formatting**: `ruff check .` / `black --check .` / `sqlfluff lint sql/`
2. **Schema & Unit Testing**: `pytest tests/` verifying chunking logic and type conversions.
3. **Docker Build Validation**: `docker build -t ingest-engine:test .` to ensure container builds without missing dependencies.

---

## 6. Interview Q&A: Git & GitHub

### Q1: What is the difference between `git merge` and `git rebase`?
* **`git merge`**: Creates a new 3-way merge commit that ties two branch histories together. It preserves the exact chronological history but creates non-linear, branching graph clutter.
* **`git rebase`**: Takes the commits from your branch and replays them one-by-one on top of the target branch. It results in a clean, perfectly linear commit history. In team pipelines, rebasing feature branches before merging keeps commit logs readable for audits.

### Q2: What is the difference between `git reset` (soft vs hard) and `git revert`?
* **`git reset --soft HEAD~1`**: Moves the HEAD ref back one commit, keeping all changes staged in the index.
* **`git reset --hard HEAD~1`**: Destroys uncommitted changes and resets the working tree and index to the previous commit. (DANGEROUS).
* **`git revert <commit_sha>`**: Creates a **new** commit that performs the exact inverse of `<commit_sha>`. This is safe for public/shared branches because it doesn't rewrite Git history.

### Q3: How do you handle accidental secrets committed to Git (e.g., DB passwords, API keys)?
1. Immediately rotate/invalidate the credential in the affected database/service.
2. Even if you make a new commit removing the password, it remains in Git history.
3. Use `git filter-repo` or BFG Repo-Cleaner to completely purge the sensitive string from all commit blobs in history, then force-push the purged refs.
4. Protect against future incidents using pre-commit hooks (`git-secrets`, `trufflehog`).
