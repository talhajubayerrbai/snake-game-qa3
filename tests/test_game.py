"""Tests for the snake-game-qa3 project."""
import subprocess
import os
import re

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def test_index_html_has_canvas():
    """index.html must contain a <canvas element."""
    path = os.path.join(REPO_ROOT, "index.html")
    with open(path) as f:
        content = f.read()
    assert "<canvas" in content, "index.html must contain a <canvas element"


def test_index_html_references_game_js():
    """index.html must reference game.js."""
    path = os.path.join(REPO_ROOT, "index.html")
    with open(path) as f:
        content = f.read()
    assert 'src="game.js"' in content or "src='game.js'" in content, \
        "index.html must reference game.js"


def test_nginx_conf_has_health_endpoint():
    """nginx.conf must define /health returning 200."""
    path = os.path.join(REPO_ROOT, "nginx.conf")
    with open(path) as f:
        content = f.read()
    assert "location = /health" in content, "nginx.conf must have /health location"
    assert "return 200" in content, "nginx.conf must return 200 for /health"


def test_nginx_conf_has_404_fallback():
    """nginx.conf must return 404 for unknown paths."""
    path = os.path.join(REPO_ROOT, "nginx.conf")
    with open(path) as f:
        content = f.read()
    assert "return 404" in content, "nginx.conf must return 404 for unknown paths"


def test_terraform_validate():
    """Terraform configuration must be valid."""
    infra_dir = os.path.join(REPO_ROOT, "infra")
    # Init without backend
    init_result = subprocess.run(
        ["terraform", "init", "-backend=false"],
        cwd=infra_dir,
        capture_output=True,
        text=True
    )
    assert init_result.returncode == 0, f"terraform init failed:\n{init_result.stderr}"

    validate_result = subprocess.run(
        ["terraform", "validate"],
        cwd=infra_dir,
        capture_output=True,
        text=True
    )
    assert validate_result.returncode == 0, \
        f"terraform validate failed:\n{validate_result.stderr}\n{validate_result.stdout}"


def test_game_js_exists():
    """game.js must exist and contain snake game logic."""
    path = os.path.join(REPO_ROOT, "game.js")
    with open(path) as f:
        content = f.read()
    assert "canvas" in content, "game.js must reference canvas"
    assert "snake" in content.lower(), "game.js must contain snake game logic"


def test_ansible_playbook_has_required_tasks():
    """Ansible playbook must install nginx and handle versioned artifact."""
    path = os.path.join(REPO_ROOT, "ansible", "configure.yml")
    with open(path) as f:
        content = f.read()
    assert "nginx" in content, "Ansible playbook must install nginx"
    assert "artifact_version" in content, "Ansible playbook must use artifact_version"
    assert "s3" in content.lower(), "Ansible playbook must fetch from S3"
