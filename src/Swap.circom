pragma circom 2.0.0;

template Swap() {
    signal input a;
    signal input b;
    signal input c;
    signal input d;
    signal input e;
    signal output f;
    f <== a*b;
 }

 component main = Swap();