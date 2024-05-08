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
	# new power of tau
	snarkjs powersoftau new bn128 7 tmp.ptau
	
	# contribute to the ceremony
	snarkjs powersoftau contribute tmp.ptau tmp1.ptau --name="First contribution"   -v -e='r'
	rm tmp.ptau
	
	# second contribute
	snarkjs powersoftau contribute tmp1.ptau tmp2.ptau --name="Second contribution" -v -e='r'
	rm tmp1.ptau

	# third contribute using third party software
	snarkjs powersoftau export challenge tmp2.ptau challenge_0003
	snarkjs powersoftau challenge contribute bn128 challenge_0003 response_0003 -e="r"
	snarkjs powersoftau import response tmp2.ptau response_0003 tmp3.ptau -n="Third contribution name"
	rm tmp2.ptau

	
	# contribute beacon to end phrase 1 
	snarkjs powersoftau beacon tmp3.ptau tmp3_beacon.ptau 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon"
	rm tmp3.ptau

	# phrase 2 
	snarkjs powersoftau prepare phase2 tmp3_beacon.ptau $(ptau) -v

$(keys): $(ptau) $(r1cs)
	# setup
	snarkjs groth16 setup $(r1cs) $(ptau) tmp.zkey

	# first contribute
	snarkjs zkey contribute tmp.zkey  tmp1.zkey --name="1st Contributor Name" -e='r'
	rm tmp.zkey

	# second contribute
	snarkjs zkey contribute tmp1.zkey tmp2.zkey --name="Second contribution Name" -v -e="Another random entropy"
	rm tmp1.zkey

	# third contribute $(pk)
	snarkjs zkey export bellman tmp2.zkey  challenge_phase2_0003
	snarkjs zkey bellman contribute bn128 challenge_phase2_0003 response_phase2_0003 -e="some random text"
	snarkjs zkey import bellman tmp2.zkey response_phase2_0003 tmp3.zkey -n="Third contribution name"
	rm tmp2.zkey

	# apply beacon
	snarkjs zkey beacon tmp3.zkey $(pk) 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
	rm tmp3.zkey

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