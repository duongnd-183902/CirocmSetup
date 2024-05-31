pragma circom 2.0.0;

template Withdraw() {
    signal input a;
    signal input b;
    signal input c;
    signal input d;
    signal output e;
    e <== a*b;
 }

 component main = Withdraw();