# Contributing to SewSmart

This guide is how the SewSmart team works together on GitHub. Read it once before your first commit.

## Branches

| Branch | Purpose | How code gets in |
| --- | --- | --- |
| `main` | Stable, demo-ready code. Updated at the end of a milestone. | Pull request from `develop` only |
| `develop` | Integration branch and the repository default. All finished work lands here. | Pull request from a work branch |
| `feature/<issue>-<short-name>` | One issue, one branch. Short-lived. | Pushed by the assignee |
| `fix/<issue>-<short-name>` | Bug fixes. | Pushed by the assignee |
| `chore/<short-name>` | Docs, tooling, configuration. | Pushed by the assignee |

Examples: `feature/12-auth-api`, `fix/31-order-status`, `chore/update-readme`.

Nobody pushes directly to `main` or `develop`. Both are protected.

## Workflow

1. **Start from an issue.** Every piece of work is a GitHub issue assigned to you. If something is missing, open an issue and ask the team lead to confirm it before you start.
2. **Create a branch from the latest `develop`.**

   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/12-auth-api
   ```

3. **Commit small and often**, using the commit format below.
4. **Sync before you open a pull request.** Resolve conflicts on your own branch, then run the code again.

   ```bash
   git pull origin develop
   ```

5. **Push and open a pull request into `develop`.**

   ```bash
   git push -u origin feature/12-auth-api
   ```

   Fill in the pull request template and write `Closes #12` in the description so the issue closes when the pull request is merged.
6. **Review.** One approval is required. Reply to every comment, push fixes to the same branch, then re-request review.
7. **Merge.** The team lead merges with **Squash and merge** and deletes the branch.

## Commit messages

Format: `<type>(<scope>): <summary>`

| Type | Use for |
| --- | --- |
| `feat` | A new feature or endpoint |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `refactor` | A change that neither fixes a bug nor adds a feature |
| `test` | Adding or fixing tests |
| `chore` | Tooling, dependencies, configuration |

Scopes: `auth`, `orders`, `tailors`, `payments`, `notifications`, `admin`, `tryon`, `mobile`.

```text
feat(auth): add register and login endpoints
fix(orders): return 404 when the order does not exist
docs(api): document the payments endpoints
```

## Pull request rules

- One issue per pull request, small enough to review in fifteen minutes.
- The base branch is always `develop`. Only the team lead opens `develop` to `main` pull requests.
- The code runs locally and you have tested the change yourself.
- No secrets, `.env` files, `node_modules/` or build output.
- API responses use the JSON keys the Flutter models expect (snake_case, for example `is_verified`, `created_at`, `price_from`).
- Endpoints follow [docs/API.md](docs/API.md). To add or change an endpoint, update that file, the backend and the comment above the Flutter service method in the same pull request.
- Attach a sample request and response, or screenshots, when behaviour changes.

## Repository layout

| Path | What it is |
| --- | --- |
| `lib/` | Flutter mobile app (customer, tailor) |
| `sewsmart_admin/` | Flutter web admin panel |
| `backend/` | Node.js + Express + MongoDB API |
| `tryon-service/` | Flask virtual try-on service |
| `docs/API.md` | API contract between the apps and the backend |
| `.github/` | Issue and pull request templates |

## Secrets

This repository is public. Never commit passwords, database URLs, JWT secrets, payment keys or any `.env` file. Commit a `.env.example` with placeholder values instead. If a secret is pushed by mistake, tell the team lead straight away so it can be replaced. Deleting the commit is not enough.

## Releases

When `develop` is stable at the end of a milestone, the team lead opens a pull request from `develop` into `main`, merges it with **Create a merge commit**, and tags the release (`v0.1.0`, `v0.2.0`, and so on).

## One-time setup

```bash
git clone https://github.com/Haiderabbas0080/sewsmart_mobile.git
cd sewsmart_mobile
git config user.name "Your Name"
git config user.email "the email on your GitHub account"
```

Use the email from your GitHub account so your commits are linked to your profile. That is how each member's contribution shows up on GitHub.
