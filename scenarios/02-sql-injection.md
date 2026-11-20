# 02 — The search box runs SQL

**Story.** Someone "optimises" the notes search by building the SQL query with
an f-string. The app still works. It is now injectable.

**Break.** In `app/app.py`, replace the parameterised `search_notes` body with
the unsafe version:
```python
rows = get_db().execute(
    f"SELECT id, title, body FROM notes WHERE title LIKE '%{term}%' ORDER BY id"
).fetchall()
```

**Observe / catch it.**
```bash
make test        # test_search_is_not_injectable FAILS
make scan-sast   # Semgrep + Bandit flag the string-built SQL with the line
```
Both a unit test and the SAST scanner catch it — belt and braces.

**Fix.** Restore the parameterised query (`... WHERE title LIKE ?`, `(f"%{term}%",)`).
Let the driver escape input; never build SQL by string concatenation.

**Why.** SAST catches a whole class of bugs before review. The test encodes the
*requirement* ("this input must be treated as data"), so it can't regress
silently.
