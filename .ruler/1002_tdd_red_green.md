# Red/Green TDD + Test format

Default development discipline for any new code.

## The cycle

1. **Red** — write the failing test first. Run it. Confirm it fails for the reason you expect (not import error, not typo).
2. **Green** — write the minimum production code to make that test pass. Resist adding untested behaviour while you're there.
3. **Refactor** — clean up while tests stay green. Run tests after each meaningful change.

## Rules

- No production code without a failing test that requires it.
- One failing test at a time. If you find a second case, note it as a TODO and finish the current cycle first.
- Tests use real data over mocks when feasible — mock only at external boundaries (network, subprocess, hardware). See "Real data over mocks" below.
- When fixing a bug: write the test that exposes it (red), then fix (green). Prevents regressions automatically.

## Test framework

Use **pytest**. Not `unittest.TestCase`. Invoke via `uv run pytest` (per `1004_package_management.md`).

For notebook (nbdev) test cells see `10_nbdev_any/2002_*` — different conventions there.

## Test format (plain-Python pytest files)

### File naming and location

- One test file per module: `test_{module}.py` next to or under a `tests/` directory mirroring `src/`.
- Test functions are prefixed `test_` (pytest auto-discovers).

### Test name expresses what is tested

Read the name aloud as a sentence. It should describe the *behaviour* and the *condition*:

```
test_is_tag_core_repo_true_when_pyproject_lists_tag_core
test_discover_repos_recursive_finds_nested_git_repos
test_sync_removes_orphan_when_file_is_no_longer_in_distribution
```

Pattern: `test_{subject}_{expected_outcome}_when_{condition}`. Avoid vague names like `test_predicate` or `test_basic`.

### Given / When / Then inside each test

Three blocks separated by blank lines and `# Given` / `# When` / `# Then` comments. Makes intent scannable without reading the assertions:

```python
def test_is_tag_core_repo_true_when_pyproject_lists_tag_core(make_repo):
    # Given a repo whose pyproject.toml declares tag-core as a dependency
    repo = make_repo(pyproject='dependencies = ["tag-core>=0.1"]')

    # When we check whether it's a tag-core repo
    result = is_tag_core_repo(repo)

    # Then the predicate returns True
    assert result is True
```

### Shared setup → pytest fixtures (factory pattern preferred)

When several tests need similar test-data, write a **factory fixture** that builds the data with parameters — not a single static fixture. The factory keeps each test's setup visible at the call site:

```python
@pytest.fixture
def make_repo(tmp_path: Path) -> Callable[..., Path]:
    "Factory: build a fake repo under tmp_path with optional pyproject.toml and subdirs."
    counter = {"n": 0}
    def _build(pyproject: str = "", subdirs: Iterable[str] = ()) -> Path:
        counter["n"] += 1
        repo = tmp_path / f"repo{counter['n']}"
        repo.mkdir()
        if pyproject: (repo / "pyproject.toml").write_text(pyproject)
        for sub in subdirs: (repo / sub).mkdir(parents=True)
        return repo
    return _build
```

Each test then reads at a glance: "Given a repo with X, When Y, Then Z." No hidden state.

### One assertion per concept

Multiple `assert` lines are fine if they verify one behaviour. If a test verifies two unrelated behaviours, split it into two tests.

### Self-contained, deterministic, ordering-independent

- Use `tmp_path` (or other pytest-managed fixtures) for any filesystem state. Never write to a path the test does not own.
- No reliance on test execution order. `pytest -p no:randomly` and `pytest --random-order` should both pass.

## Real data over mocks

Mocking is a last resort, not a default. It hides integration bugs and produces tests that pass while production fails.

### What to mock

- ✅ External processes (`ffprobe`, media players, `git`, subprocesses you don't own)
- ✅ System resources (writes to `/var/log/*`, hardware devices, sound, screen)
- ✅ Time-dependent behaviour (when testing specific dates/times — use `freezegun` or inject the clock)
- ✅ Network calls to third-party services

### What NOT to mock

- ❌ Database operations — use in-memory SQLite or `tmp_path` for real file-backed dbs
- ❌ File operations — use `tmp_path` and let pytest clean up
- ❌ Internal application logic — if you're mocking your own code to test your own code, the test boundary is wrong

### Example: real filesystem, no mocks needed

```python
def test_load_config_returns_parsed_dict_when_file_is_valid_json(tmp_path):
    # Given a config file containing valid JSON
    config = tmp_path / "config.json"
    config.write_text('{"name": "foo", "size": 42}')

    # When we load it
    result = load_config(config)

    # Then the parsed dict matches the file content
    assert result == {"name": "foo", "size": 42}
```

### Example: mock only the external boundary

```python
def test_fetch_user_returns_cached_when_network_unreachable(tmp_path, monkeypatch):
    # Given a cache file with a known user and a network that always fails
    cache = tmp_path / "users.json"
    cache.write_text('{"alice": {"id": 1}}')
    monkeypatch.setattr("requests.get", lambda *a, **kw: (_ for _ in ()).throw(ConnectionError()))

    # When we fetch "alice"
    user = fetch_user("alice", cache_path=cache)

    # Then the cached value is returned (no exception, no real network call)
    assert user == {"id": 1}
```

## When TDD does not apply

- Throwaway exploration / spikes (delete the spike when done).
- Pure config / docs / data files (no behaviour to test).
- Tracer-bullet UI work where the feedback loop is visual (still write tests for the underlying logic once the UI stabilises).
