---
author: Yann Orlarey, Stéphane Letz
title: The Future of Faust
subtitle: Ondemand and Co.
institute: EMERAUDE
theme: "metropolis"
colortheme: "crane"
fontsize: 10pt
urlcolor: red
linkstyle: bold
date: IFC 2024
lang: us-EN
section-titles: false
toc: false


---

# Part 1 : A brief History of Multirate in Faust

## 2009: Semantics of multirate Faust

The monorate, always active, model is simple, but not always enough.

![](images/sem-faust-mr.png)


## 2015: Mute, Enable and Control

![](images/enable.png)

- 2015: `mute(x,y)` like `x*y` but the computation of `x` can be suspend when `y` is 0.
- later `mute` renamed in `enable` and variant `control` added
- later extended to `-vec` mode

## 2020: Ondemand

![](images/ondemand-0.png)

- 2020: Till Bovermann asks for _demand-rate computations_
- 2020: Specification of _ondemand_
- 2022: Proof of concept presented at IFC-22
- 2024: _Ondemand_ officially introduced at IFC-24

# Part 2 : Ondemand

## Introduction

### Objective

Provide _Multirate_ and _Call by Need_ computation, while preserving _efficiency_ and _simple semantics_

### Multirate Computation

- Frequency domain
- Upsampling
- Downsampling

### Call by Need

- Pay for what you use
- Controling when computations are done
- Music Composition style computation

## Ondemand Semantics


`ondemand(C)` is `C` applied to downsampled input signals, the resulting signals being upsampled.

![](images/ondemand-schema.png)


### Semantic rule

$$
\inference[(od)]{
    \semc{C}(S_1<*H,...,S_n<*H) = (Y_1,...,Y_m)\\
}{
    \semc{\od{C}}(H,S_1,...,S_n) = (Y_1*>H,...,Y_m*>H)
} 
$$ 



## Downsampling

$S_i<*H$ is the downsampling of $S_i$, based on the clock signal $H$. 

\begin{table}[!ht]
\centering
\begin{tabular}{cccccc}
\hline
$t$ & $S_i$  & $H$   & $S_i<*H$  & $\down{H}$ & $t'$ \\ \hline
0   &  a     & 1     & a         & 0          & 0   \\
1   &  b     & 0     &           &            &     \\
2   &  c     & 0     &           &            &     \\
3   &  d     & 1     & d         & 3          & 1   \\
4   &  f     & 1     & f         & 4          & 2   \\
5   &  g     & 0     &           &            &     \\ \hline
\end{tabular}
\caption{Example of downsampling}
\label{tab:downsampling}
\end{table}

### Semantic rule

$$
\inference[(down)]{
\down{H} = \{n\in\N <> \sems{H}(n)=1\}
}{
\sems{S_i<*H}(t) = \sems{S_i}(\down{H}(t))
}
$$


## Upsampling

$S_i*>H$ is the upsampling of $S_i$ according to clock signal $H$. 

\begin{table}[!ht]
\centering 
\begin{tabular}{cccccc}
\hline
$t'$ & $S_i$ & $H$   & $S_i*>H$  & $\up{H}$ &$t$  \\ \hline
0    & a     & 1     & a         & 0        & 0 \\
1    & d     & 0     & a         & 0        & 1 \\
2    & f     & 0     & a         & 0        & 2 \\
     &       & 1     & d         & 1        & 3 \\
     &       & 1     & f         & 2        & 4 \\
     &       & 0     & f         & 2        & 5 \\ \hline
\end{tabular}
\caption{Example of upsampling}
\label{tab:upsampling}
\end{table}

### Semantic rule

$$
\inference[(up)]{
\up{H}(t) = \sum_{i=0}^t \sems{H}(i) - 1
}{
\sems{S_i*>H}(t) = \sems{S_i}(\up{H}(t))
}
$$

## Example 1: Sample and Hold

_Sample and Hold_ is simply the ondemand version of the identity function.

### 1: without ondemand

```faust
SH = (X,_:select2) ~ _ with { X = _,_ <: !,_,_,!; };
```

### 2: with ondemand


```faust
SH = ondemand(_);
```

## Example 1: Generated code

### 1: without ondemand

```C
for (int i=0; i<count; i++) {
    fVec0SE[0] = ((int((float)input0[i])) ? 
                 (float)input1[i] : fVec0SE[1]);
    output0[i] = (FAUSTFLOAT)(fVec0SE[0]); 
    fVec0SE[1] = fVec0SE[0];
}
```

### 2: with ondemand


```C
for (int i=0; i<count; i++) {
    fTemp0SE = (float)input1[i]; 
    if ((float)input0[i]) {
        fPermVar0SE = fTemp0SE;
    }
    output0[i] = (FAUSTFLOAT)(fPermVar0SE); 
}
```


## Example 2: downsampled noise, without ondemand


![](images/down-noise-sh.png)

### Faust code

```C
process = beat(100), no.noise : SH;
```



## Example 2: downsampled noise, with ondemand

![](images/down-noise-od.png)


### Faust code

```C
process = beat(100) :  ondemand(no.noise);
```


## Example 2: Generated code, without ondemand

```C
for (int i=0; i<count; i++) {
    iVec0SI[0] = ((iVec0SI[1] + 1) % 100);
    iVec3SI[0] = ((1103515245 * iVec3SI[1]) + 12345);
    fVec2SI[0] = (((iVec0SI[0] == 0)) ? 
                 (4.656613e-10f * float(iVec3SI[0])) 
                 : fVec2SI[1]);
    output0[i] = (FAUSTFLOAT)(fVec2SI[0]);
    fVec2SI[1] = fVec2SI[0];
    iVec3SI[1] = iVec3SI[0];
    iVec0SI[1] = iVec0SI[0];
}
```


## Example 2: Generated code, with ondemand

```C
for (int i=0; i<count; i++) {
    iVec0SI[0] = ((iVec0SI[1] + 1) % 100);
    if ((iVec0SI[0] == 0)) {
        iVec2SI[0] = ((1103515245 * iVec2SI[1]) + 12345);
        fPermVar0SI = (4.656613e-10f * float(iVec2SI[0]));
        iVec2SI[1] = iVec2SI[0];
    }
    output0[i] = (FAUSTFLOAT)(fPermVar0SI);  
    iVec0SI[1] = iVec0SI[0];
}
```

# Part 3 : ondemand variants

## Oversampling

![](images/oversampling.png)

### `oversampling(C)`

Circuit `C` is run $N$ times faster than the surrounding circuit. The value of sampling frequency, as seen from within `C`, is adapted accordingly.

## Undersampling

![](images/undersampling.png)

### `undersampling(C)`

Circuit `C` is run $N$ times slower than the surrounding circuit. The value of sampling frequency, as seen from within `C`, is adapted accordingly.

## Switch

![](images/switch.png)

### `swith(C0,C1,...,Ck)`

Activate one of the `Ci` circuits according to the control input `c`. All the circuits must have the same type $n->m$.

## Interleave

![](images/interleave.png)

### `interleave(C)`

Assuming `C` is of type $n->n$, `interleave(C)` will distribute the incomming samples to each of the $n$ inputs of `C`, the run `C` once, and then interleave each output value to the output signal.

## Conclusion

By allowing to control precisely when computations are done, Ondemand and its variants will facilitate :

- Frequency domain computation
- Oversampling and Undersampling
- Composition style _Call by Need_ computation

while

- Increasing the efficiency of the code
- Preserving the simple semantics of Faust
- Being circuit primitives, in the spirit of Faust
