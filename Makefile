SHELL = bash

circom = dnd.circom
r1cs = dnd.r1cs
wasm = dnd_js/dnd.wasm
witness = dnd_js/generate_witness.js
compile_outputs = dnd_js/witness_calculator.js $(r1cs) $(wasm) $(witness)
pk = dnd.zkey
vk = dnd.json
ptau = dnd.ptau
keys = $(pk) $(vk)
pubInputs = dnd.input.json
wit = dnd.wtns
pf = proof.json
inst = public.json
prove_outputs = $(pf) $(inst)

all: verify

$(compile_outputs): $(circom)
	circom $< --r1cs --wasm

$(ptau):
	snarkjs powersoftau new bn128 12 tmp.ptau
	snarkjs powersoftau contribute tmp.ptau tmp1.ptau --name="First contribution"   -v -e='0xccc49d88284aaf7aeb9889c5a8c86dadb00ce1e74f7eaec8bc51193e228ea0f9'
	# snarkjs powersoftau contribute tmp1.ptau tmp2.ptau --name="Second contribution" -v -e='0x6944633152399443603624224235593869484651980060375192863695182892'

	# snarkjs powersoftau export challenge tmp2.ptau challenge_0003
	# snarkjs powersoftau challenge contribute bn128 challenge_0003 response_0003 -e="bullshit"
	# snarkjs powersoftau import response tm2.ptau response_0003 tmp3.ptau -n="Third contribution name"

	rm tmp.ptau
	# rm tmp1.ptau
	# rm tmp2.ptau

	snarkjs powersoftau prepare phase2 tmp1.ptau $(ptau) -v
	rm tmp1.ptau

$(keys): $(ptau) $(r1cs)
	snarkjs groth16 setup $(r1cs) $(ptau) tmp.zkey
	snarkjs zkey contribute tmp.zkey $(pk) --name="1st Contributor Name" -e='r'
	rm tmp.zkey
	snarkjs zkey export verificationkey $(pk) $(vk)

$(wit): $(pubInputs) $(wasm) $(witness)
	node $(witness) $(wasm) $(pubInputs) $@

$(prove_outputs): $(wit) $(pk)
	snarkjs groth16 prove $(pk) $(wit) $(pf) $(inst)

.PHONY = verify clean calldata

verify: $(pf) $(inst) $(vk)
	snarkjs groth16 verify $(vk) $(inst) $(pf)

clean:
	rm -f $(compile_outputs) $(ptau) $(keys) $(wit) $(prove_outputs) verifier.sol rm tmp.ptau rm tmp1.ptau rm tmp.zkey
	rmdir dnd_js

verifier.sol: $(pk)
	snarkjs zkey export solidityverifier $(pk) $@

calldata: $(wit) $(prove_outputs)
	snarkjs generatecall