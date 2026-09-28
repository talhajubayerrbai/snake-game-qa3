(function() {
  'use strict';

  const canvas = document.getElementById('gameCanvas');
  const ctx = canvas.getContext('2d');
  const scoreEl = document.getElementById('score');
  const highScoreEl = document.getElementById('high-score');
  const messageEl = document.getElementById('message');

  const GRID = 20;
  const COLS = canvas.width / GRID;
  const ROWS = canvas.height / GRID;
  const TICK_MS = 120;

  const COLOR_BG    = '#1a1a2e';
  const COLOR_GRID  = '#16213e';
  const COLOR_SNAKE = '#00d4aa';
  const COLOR_HEAD  = '#00ffcc';
  const COLOR_FOOD  = '#ff6b6b';

  let snake, dir, nextDir, food, score, highScore, gameLoop, state, paused;

  function init() {
    snake = [{x: 10, y: 10}, {x: 9, y: 10}, {x: 8, y: 10}];
    dir = {x: 1, y: 0};
    nextDir = {x: 1, y: 0};
    score = 0;
    paused = false;
    state = 'waiting'; // waiting | running | over
    highScore = highScore || 0;
    updateScore();
    placeFood();
    draw();
  }

  function placeFood() {
    let pos;
    do {
      pos = {x: Math.floor(Math.random() * COLS), y: Math.floor(Math.random() * ROWS)};
    } while (snake.some(s => s.x === pos.x && s.y === pos.y));
    food = pos;
  }

  function updateScore() {
    scoreEl.textContent = score;
    if (score > highScore) { highScore = score; }
    highScoreEl.textContent = highScore;
  }

  function tick() {
    if (paused || state !== 'running') return;
    dir = nextDir;
    const head = {x: snake[0].x + dir.x, y: snake[0].y + dir.y};

    // Wall collision
    if (head.x < 0 || head.x >= COLS || head.y < 0 || head.y >= ROWS) {
      endGame(); return;
    }
    // Self collision
    if (snake.some(s => s.x === head.x && s.y === head.y)) {
      endGame(); return;
    }

    snake.unshift(head);

    if (head.x === food.x && head.y === food.y) {
      score += 10;
      updateScore();
      placeFood();
    } else {
      snake.pop();
    }
    draw();
  }

  function endGame() {
    state = 'over';
    clearInterval(gameLoop);
    messageEl.textContent = 'Game Over! Score: ' + score + ' — Press any arrow / WASD to restart';
    draw();
  }

  function start() {
    if (gameLoop) clearInterval(gameLoop);
    init();
    state = 'running';
    messageEl.textContent = '';
    gameLoop = setInterval(tick, TICK_MS);
  }

  function draw() {
    // Background
    ctx.fillStyle = COLOR_BG;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Grid
    ctx.strokeStyle = COLOR_GRID;
    ctx.lineWidth = 0.5;
    for (let x = 0; x <= canvas.width; x += GRID) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke();
    }
    for (let y = 0; y <= canvas.height; y += GRID) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke();
    }

    // Food
    ctx.fillStyle = COLOR_FOOD;
    ctx.beginPath();
    ctx.arc(food.x * GRID + GRID/2, food.y * GRID + GRID/2, GRID/2 - 2, 0, Math.PI * 2);
    ctx.fill();

    // Snake
    snake.forEach(function(seg, i) {
      ctx.fillStyle = i === 0 ? COLOR_HEAD : COLOR_SNAKE;
      ctx.beginPath();
      ctx.roundRect(seg.x * GRID + 1, seg.y * GRID + 1, GRID - 2, GRID - 2, 3);
      ctx.fill();
    });
  }

  document.addEventListener('keydown', function(e) {
    const key = e.key;
    if (key === 'p' || key === 'P') {
      if (state === 'running') {
        paused = !paused;
        messageEl.textContent = paused ? 'Paused — Press P to resume' : '';
      }
      return;
    }
    const moves = {
      ArrowUp:    {x: 0,  y: -1},
      ArrowDown:  {x: 0,  y:  1},
      ArrowLeft:  {x: -1, y:  0},
      ArrowRight: {x: 1,  y:  0},
      w: {x: 0,  y: -1}, W: {x: 0,  y: -1},
      s: {x: 0,  y:  1}, S: {x: 0,  y:  1},
      a: {x: -1, y:  0}, A: {x: -1, y:  0},
      d: {x: 1,  y:  0}, D: {x: 1,  y:  0}
    };
    if (!moves[key]) return;
    e.preventDefault();
    const m = moves[key];
    // Prevent 180-degree reversal
    if (m.x === -dir.x && m.y === -dir.y) return;
    if (state === 'waiting' || state === 'over') {
      nextDir = m;
      start();
    } else {
      nextDir = m;
    }
  });

  init();
})();
