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

# Function to generate random hexadecimal text
define rHex
	$(shell cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | fold -w 64 | head -n 1)
endef


all: verify

$(compile_outputs): $(circom)
	circom $< --r1cs --wasm

$(ptau):
	# new power of tau
	snarkjs powersoftau new bn128 7 tmp.ptau
	
	# contribute to the ceremony
	$(eval RANDOM_HEX := $(call rHex))
	snarkjs powersoftau contribute tmp.ptau tmp1.ptau --name="First contribution"   -v -e="$(RANDOM_HEX)"
	rm tmp.ptau
	
	# second contribute
	$(eval RANDOM_HEX := $(call rHex))
	snarkjs powersoftau contribute tmp1.ptau tmp2.ptau --name="Second contribution" -v -e="$(RANDOM_HEX)"
	rm tmp1.ptau

	# third contribute using third party software
	$(eval RANDOM_HEX := $(call rHex))
	snarkjs powersoftau export challenge tmp2.ptau challenge_0003
	snarkjs powersoftau challenge contribute bn128 challenge_0003 response_0003 -e="$(RANDOM_HEX)"
	snarkjs powersoftau import response tmp2.ptau response_0003 tmp3.ptau -n="Third contribution"
	rm tmp2.ptau
	rm challenge_0003
	rm response_0003

	
	# contribute beacon to end phrase 1 
	$(eval RANDOM_HEX := $(call rHex))
	snarkjs powersoftau beacon tmp3.ptau tmp3_beacon.ptau "$(RANDOM_HEX)" 10 -n="Final Beacon"
	rm tmp3.ptau

	# phrase 2 
	snarkjs powersoftau prepare phase2 tmp3_beacon.ptau $(ptau) -v
	rm tmp3_beacon.ptau

$(keys): $(ptau) $(r1cs)
	# setup
	snarkjs groth16 setup $(r1cs) $(ptau) tmp.zkey

	# first contribute
	$(eval RANDOM_HEX := $(call rHex))
	snarkjs zkey contribute tmp.zkey  tmp1.zkey --name="1st Contributor Name" -e="$(RANDOM_HEX)"
	rm tmp.zkey

	# second contribute
	$(eval RANDOM_HEX := $(call rHex))
	snarkjs zkey contribute tmp1.zkey tmp2.zkey --name="Second contribution Name" -v -e="$(RANDOM_HEX)"
	rm tmp1.zkey

	# third contribute
	$(eval RANDOM_HEX := $(call rHex))
	snarkjs zkey export bellman tmp2.zkey  challenge_phase2_0003
	snarkjs zkey bellman contribute bn128 challenge_phase2_0003 response_phase2_0003 -e="$(RANDOM_HEX)"
	snarkjs zkey import bellman tmp2.zkey response_phase2_0003 tmp3.zkey -n="Third contribution name"
	rm tmp2.zkey
	rm challenge_phase2_0003
	rm response_phase2_0003

	# apply beacon
	$(eval RANDOM_HEX := $(call rHex))
	snarkjs zkey beacon tmp3.zkey $(pk) "$(RANDOM_HEX)" 10 -n="Final Beacon phase2"
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
	rm -f $(compile_outputs) $(ptau) $(keys) $(wit) $(prove_outputs) verifier.sol 
	rmdir dnd_js

verifier.sol: $(pk)
	snarkjs zkey export solidityverifier $(pk) $@

calldata: $(wit) $(prove_outputs)
	snarkjs generatecall