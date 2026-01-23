const fs = require('fs');
const path = require('path');

const program = fs
	.readFileSync(path.join(__dirname, 'input.txt'), 'utf8')
	.trim()
	.split(',')
	.map((num) => parseInt(num, 10));

function runIntcode(mem, inputs) {
	const memory = mem.slice();
	let ip = 0;
	let relativeBase = 0;
	let inputIndex = 0;
	const outputs = [];

	const read = (addr) => (addr >= 0 ? memory[addr] ?? 0 : (() => { throw new Error('negative addr'); })());
	const write = (addr, value) => {
		if (addr < 0) throw new Error('negative addr');
		memory[addr] = value;
	};
	const param = (mode, offset) => {
		const value = read(ip + offset);
		if (mode === 0) return read(value);
		if (mode === 1) return value;
		if (mode === 2) return read(relativeBase + value);
		throw new Error(`invalid mode ${mode}`);
	};
	const addr = (mode, offset) => {
		const value = read(ip + offset);
		if (mode === 0) return value;
		if (mode === 2) return relativeBase + value;
		if (mode === 1) return value;
		throw new Error(`invalid mode ${mode}`);
	};

	while (true) {
		const instruction = read(ip);
		const opcode = instruction % 100;
		const mode1 = Math.floor(instruction / 100) % 10;
		const mode2 = Math.floor(instruction / 1000) % 10;
		const mode3 = Math.floor(instruction / 10000) % 10;

		switch (opcode) {
			case 1: {
				const a = param(mode1, 1);
				const b = param(mode2, 2);
				write(addr(mode3, 3), a + b);
				ip += 4;
				break;
			}
			case 2: {
				const a = param(mode1, 1);
				const b = param(mode2, 2);
				write(addr(mode3, 3), a * b);
				ip += 4;
				break;
			}
			case 3: {
				if (inputIndex >= inputs.length) {
					throw new Error('input needed');
				}
				write(addr(mode1, 1), inputs[inputIndex++]);
				ip += 2;
				break;
			}
			case 4: {
				outputs.push(param(mode1, 1));
				ip += 2;
				break;
			}
			case 5: {
				const test = param(mode1, 1);
				const target = param(mode2, 2);
				ip = test !== 0 ? target : ip + 3;
				break;
			}
			case 6: {
				const test = param(mode1, 1);
				const target = param(mode2, 2);
				ip = test === 0 ? target : ip + 3;
				break;
			}
			case 7: {
				const a = param(mode1, 1);
				const b = param(mode2, 2);
				write(addr(mode3, 3), a < b ? 1 : 0);
				ip += 4;
				break;
			}
			case 8: {
				const a = param(mode1, 1);
				const b = param(mode2, 2);
				write(addr(mode3, 3), a === b ? 1 : 0);
				ip += 4;
				break;
			}
			case 9: {
				relativeBase += param(mode1, 1);
				ip += 2;
				break;
			}
			case 99:
				return outputs;
			default:
				throw new Error(`Unknown opcode ${opcode} at ${ip}`);
		}
	}
}

function buildGrid(ascii) {
	const lines = String.fromCharCode(...ascii).trim().split('\n');
	const grid = lines.map((line) => line.split(''));
	return { grid, width: grid[0].length, height: grid.length };
}

function isScaffold(ch) {
	return ch === '#' || ch === '^' || ch === 'v' || ch === '<' || ch === '>';
}

function alignmentSum(grid) {
	let sum = 0;
	for (let y = 1; y < grid.length - 1; y++) {
		for (let x = 1; x < grid[y].length - 1; x++) {
			if (!isScaffold(grid[y][x])) continue;
			if (
				isScaffold(grid[y - 1][x]) &&
				isScaffold(grid[y + 1][x]) &&
				isScaffold(grid[y][x - 1]) &&
				isScaffold(grid[y][x + 1])
			) {
				sum += x * y;
			}
		}
	}
	return sum;
}

const directions = [
	{ dx: 0, dy: -1, ch: '^' },
	{ dx: 1, dy: 0, ch: '>' },
	{ dx: 0, dy: 1, ch: 'v' },
	{ dx: -1, dy: 0, ch: '<' },
];

function findRobot(grid) {
	for (let y = 0; y < grid.length; y++) {
		for (let x = 0; x < grid[y].length; x++) {
			const ch = grid[y][x];
			const dirIndex = directions.findIndex((d) => d.ch === ch);
			if (dirIndex !== -1) {
				return { x, y, dirIndex };
			}
		}
	}
	throw new Error('robot not found');
}

function tracePath(grid) {
	let { x, y, dirIndex } = findRobot(grid);
	const path = [];
	const height = grid.length;
	const width = grid[0].length;

	const canMove = (nx, ny) => ny >= 0 && ny < height && nx >= 0 && nx < width && isScaffold(grid[ny][nx]);

	while (true) {
		let steps = 0;
		const dir = directions[dirIndex];
		while (canMove(x + dir.dx, y + dir.dy)) {
			x += dir.dx;
			y += dir.dy;
			steps += 1;
		}
		if (steps > 0) {
			path.push(String(steps));
		}
		const left = (dirIndex + 3) % 4;
		const right = (dirIndex + 1) % 4;
		const leftDir = directions[left];
		const rightDir = directions[right];
		if (canMove(x + leftDir.dx, y + leftDir.dy)) {
			path.push('L');
			dirIndex = left;
			continue;
		}
		if (canMove(x + rightDir.dx, y + rightDir.dy)) {
			path.push('R');
			dirIndex = right;
			continue;
		}
		break;
	}

	return path;
}

function tokensToString(tokens) {
	return tokens.join(',');
}

function fitsRoutine(tokens) {
	return tokensToString(tokens).length <= 20;
}

function compressPath(tokens) {
	const routines = { A: null, B: null, C: null };

	function helper(index, main) {
		if (index >= tokens.length) {
			return { main, routines };
		}
		for (const label of ['A', 'B', 'C']) {
			const routine = routines[label];
			if (routine) {
				const len = routine.length;
				const slice = tokens.slice(index, index + len);
				if (slice.join(',') === routine.join(',')) {
					const next = helper(index + len, [...main, label]);
					if (next) return next;
				}
			} else {
				for (let end = index + 1; end <= tokens.length; end++) {
					const candidate = tokens.slice(index, end);
					if (!fitsRoutine(candidate)) break;
					if (candidate[0] === 'L' || candidate[0] === 'R') {
						routines[label] = candidate;
						const next = helper(end, [...main, label]);
						if (next) return next;
						routines[label] = null;
					}
				}
			}
		}
		return null;
	}

	return helper(0, []);
}

function buildInput(main, routines) {
	const lines = [
		tokensToString(main),
		tokensToString(routines.A),
		tokensToString(routines.B),
		tokensToString(routines.C),
		'n',
	];
	return lines.join('\n').split('').map((ch) => ch.charCodeAt(0)).concat([10]);
}

function nowMs() {
	return typeof performance !== 'undefined'
		? performance.now()
		: Number(process.hrtime.bigint()) / 1e6;
}

const overallStart = nowMs();

const part1Start = nowMs();
const output = runIntcode(program, []);
const { grid } = buildGrid(output);
const part1 = alignmentSum(grid);
const part1Ms = nowMs() - part1Start;

const part2Start = nowMs();
const pathTokens = tracePath(grid);
const compression = compressPath(pathTokens);
if (!compression) {
	throw new Error('Failed to compress path');
}

const movementInput = buildInput(compression.main, compression.routines);
const programWithVacuum = program.slice();
programWithVacuum[0] = 2;
const outputs = runIntcode(programWithVacuum, movementInput);
const part2 = outputs[outputs.length - 1];
const part2Ms = nowMs() - part2Start;
const overallMs = nowMs() - overallStart;

console.log('Part 1:', part1, `(${part1Ms.toFixed(2)} ms)`);
console.log('Part 2:', part2, `(${part2Ms.toFixed(2)} ms)`);
console.log('Total:', overallMs.toFixed(2), 'ms');
