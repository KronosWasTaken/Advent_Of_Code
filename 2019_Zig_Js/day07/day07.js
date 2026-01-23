const fs = require('fs');
const path = require('path');

const input = fs
	.readFileSync(path.join(__dirname, 'input.txt'), 'utf8')
	.toString()
	.trim()
	.split(',')
	.map((num) => parseInt(num, 10));

function createComputer(program, phase) {
	return {
		mem: program.slice(),
		ip: 0,
		inputs: [phase],
		inputIndex: 0,
		halted: false,
	};
}

function readParam(mem, ip, mode) {
	const value = mem[ip];
	return mode === 0 ? mem[value] : value;
}

function runUntilOutput(comp, inputSignal) {
	if (inputSignal !== undefined) {
		comp.inputs.push(inputSignal);
	}

	const mem = comp.mem;
	let ip = comp.ip;
	let inputIndex = comp.inputIndex;
	const inputs = comp.inputs;

	while (true) {
		const instruction = mem[ip];
		const opcode = instruction % 100;
		const mode1 = Math.floor(instruction / 100) % 10;
		const mode2 = Math.floor(instruction / 1000) % 10;

		switch (opcode) {
			case 1: {
				const a = readParam(mem, ip + 1, mode1);
				const b = readParam(mem, ip + 2, mode2);
				const dest = mem[ip + 3];
				mem[dest] = a + b;
				ip += 4;
				break;
			}
			case 2: {
				const a = readParam(mem, ip + 1, mode1);
				const b = readParam(mem, ip + 2, mode2);
				const dest = mem[ip + 3];
				mem[dest] = a * b;
				ip += 4;
				break;
			}
			case 3: {
				if (inputIndex >= inputs.length) {
					comp.ip = ip;
					comp.inputIndex = inputIndex;
					return null;
				}
				const dest = mem[ip + 1];
				mem[dest] = inputs[inputIndex++];
				ip += 2;
				break;
			}
			case 4: {
				const output = readParam(mem, ip + 1, mode1);
				ip += 2;
				comp.ip = ip;
				comp.inputIndex = inputIndex;
				return output;
			}
			case 5: {
				const test = readParam(mem, ip + 1, mode1);
				const target = readParam(mem, ip + 2, mode2);
				ip = test !== 0 ? target : ip + 3;
				break;
			}
			case 6: {
				const test = readParam(mem, ip + 1, mode1);
				const target = readParam(mem, ip + 2, mode2);
				ip = test === 0 ? target : ip + 3;
				break;
			}
			case 7: {
				const a = readParam(mem, ip + 1, mode1);
				const b = readParam(mem, ip + 2, mode2);
				const dest = mem[ip + 3];
				mem[dest] = a < b ? 1 : 0;
				ip += 4;
				break;
			}
			case 8: {
				const a = readParam(mem, ip + 1, mode1);
				const b = readParam(mem, ip + 2, mode2);
				const dest = mem[ip + 3];
				mem[dest] = a === b ? 1 : 0;
				ip += 4;
				break;
			}
			case 99:
				comp.halted = true;
				comp.ip = ip;
				comp.inputIndex = inputIndex;
				return null;
			default:
				throw new Error(`Unknown opcode ${opcode} at ${ip}`);
		}
	}
}

function permute(values, callback) {
	const arr = values.slice();
	const c = new Array(arr.length).fill(0);
	callback(arr.slice());
	let i = 0;
	while (i < arr.length) {
		if (c[i] < i) {
			if (i % 2 === 0) {
				[arr[0], arr[i]] = [arr[i], arr[0]];
			} else {
				[arr[c[i]], arr[i]] = [arr[i], arr[c[i]]];
			}
			callback(arr.slice());
			c[i] += 1;
			i = 0;
		} else {
			c[i] = 0;
			i += 1;
		}
	}
}

function nowMs() {
	return typeof performance !== 'undefined'
		? performance.now()
		: Number(process.hrtime.bigint()) / 1e6;
}

const overallStart = nowMs();

const part1Start = nowMs();
let maxOutputPart1 = Number.MIN_SAFE_INTEGER;
permute([0, 1, 2, 3, 4], (phases) => {
	let signal = 0;
	for (const phase of phases) {
		const comp = createComputer(input, phase);
		signal = runUntilOutput(comp, signal);
	}
	if (signal > maxOutputPart1) {
		maxOutputPart1 = signal;
	}
});
const part1Ms = nowMs() - part1Start;

const part2Start = nowMs();
let maxOutputPart2 = Number.MIN_SAFE_INTEGER;
permute([5, 6, 7, 8, 9], (phases) => {
	const amps = phases.map((phase) => createComputer(input, phase));
	let signal = 0;
	let lastOutput = 0;
	while (!amps[amps.length - 1].halted) {
		for (const amp of amps) {
			const output = runUntilOutput(amp, signal);
			if (output !== null) {
				signal = output;
				lastOutput = signal;
			}
		}
	}
	if (lastOutput > maxOutputPart2) {
		maxOutputPart2 = lastOutput;
	}
});
const part2Ms = nowMs() - part2Start;
const overallMs = nowMs() - overallStart;

console.log('Part 1:', maxOutputPart1, `(${part1Ms.toFixed(2)} ms)`);
console.log('Part 2:', maxOutputPart2, `(${part2Ms.toFixed(2)} ms)`);
console.log('Total:', overallMs.toFixed(2), 'ms');
