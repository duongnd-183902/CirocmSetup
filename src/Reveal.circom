pragma circom 2.0.0;

template Reveal() {
    signal input a;
    signal input b;
    signal input c;
    signal output d;
    d <== a*b;
 }

 component main = Reveal();