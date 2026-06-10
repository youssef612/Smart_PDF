# JtvDoFnT9sgea5bojQOeJD1TMGEtioZkvrJkKVuS — Extracted Content

*Characters: 76,851 | marker-pdf*

---

![](_page_0_Picture_0.jpeg)

![](_page_0_Picture_1.jpeg)

![](_page_0_Picture_2.jpeg)

# **Integral Equations**

**Prepared by**

# *Dr. Gamal Ahmed Mosa*

**Mathematics Department - Faculty of Science, Benha University - Egypt**

# 0. Contents

| 1 | Introduction       |                                                                   |                                                           | 2  |
|---|--------------------|-------------------------------------------------------------------|-----------------------------------------------------------|----|
| 2 | Integral Equations |                                                                   |                                                           | 3  |
|   | 2.1                |                                                                   | Integral equations                                        | 3  |
|   | 2.2                | Classification of integral equations                              |                                                           | 4  |
|   | 2.3                | The relation between initial and boundary value problems with IEs |                                                           | 6  |
|   | 2.4                | Existence and uniqueness theorems .                               |                                                           | 14 |
|   | 2.5                |                                                                   | Kernels of IEs                                            | 18 |
|   |                    | 2.5.1                                                             | (discontinuous) kernels                                   | 19 |
|   | 2.6                |                                                                   | Analytical methods for solving IEs with continuous kernel | 20 |
|   |                    | 2.6.1                                                             | Degenerate kernel method                                  | 20 |
|   |                    | 2.6.2                                                             | Successive approximation method[?]                        | 23 |
|   |                    | 2.6.3                                                             | Resolvent kernel method                                   | 26 |
|   |                    | 2.6.4                                                             | Laplace Transformation Method                             | 31 |
|   | 2.7                | Numerical methods                                                 |                                                           | 33 |
|   |                    | 2.7.1                                                             | Quadrature methods for FIE and VIE                        | 33 |
|   |                    | 2.7.2                                                             | Collocation method for FIEs and VIEs .                    | 36 |
|   |                    | 2.7.3                                                             | Galerkin method for FIEs and VIEs                         | 37 |
|   |                    | 2.7.4                                                             | Homotopy Analysis Method                                  | 38 |
|   |                    | 2.7.5                                                             | Homotopy Perturbation Method                              | 39 |
|   |                    | 2.7.6                                                             | Adomian Decomposition Method                              | 40 |
|   | References         |                                                                   |                                                           | 48 |

# <span id="page-2-0"></span>1. Introduction

It is important to note that integral equations arise in engineering, physics, chemistry, and biological problems. Many initial and boundary value problems associated with the ordinary and partial differential equations can be cast into the integral equations of Volterra and Fredholm types, respectively. Engineering problems can be mathematically described by differential equations model. Similarly, problems arising in electric circuits, chemical kinetics, and transfer of heat in a medium can all be represented mathematically as differential equations. These differential equations can be transformed to the equivalent integral equations of Volterra and Fredholm types. On the other hand, there are many physical problems that are governed by the integral equations and these equations can be easily transformed to the differential equations.

The purpose of this review article is to clarify the importance of integral equations in natural and physical applications by providing the basic concepts of integral equations and the relations between differential equations with integral equations, moreover, how to convert between them and then focus on some different numerically solutions methods of integral equations

later in next sections we present some points to study as a future work.

# <span id="page-3-0"></span>2. Integral Equations

# <span id="page-3-1"></span>2.1 Integral equations

Integral equations (IEs) exist in nature and appear in various fields of science and engineering [\[10,](#page-42-1) [8,](#page-42-2) [83\]](#page-48-0). Accordingly, there are many computational approaches to approximate the solutions of IEs [\[26,](#page-44-0) [45,](#page-45-0) [46,](#page-45-1) [65\]](#page-46-0). The IE is an equation in which the unknown function ϕ(x) appears inside an integration. The most standard type of integral equation is:

<span id="page-3-3"></span>
$$r(x)\phi(x) = f(x) + \lambda \int_{\alpha(x)}^{\beta(x)} K(x,y)\phi(y)dy,$$
(2.1)

where

- 1. r(x) is a function defining the kind of the IE,
- i. if r(x) = 0, then the IE is of the first kind,
- ii. if r(x)=µ̸=0, µ is constant, then the IE is of the second kind,
- 2. the kernel K(x, y) is known function,
- 3. the function f(x) is called free term of the IE,
- i. If f(x) = 0 then equation [\(2.1\)](#page-3-3) is called homogenous integral equation,
- ii. If f(x) ̸= 0 then equation [\(2.1\)](#page-3-3) is called inhomogeneous integral equation.
- 4. the unknown function ϕ(x) appears inside and outside the integration that shall be determined and the linearity of the IE depends on its power.
- <span id="page-3-2"></span>5. λ is called the IE parameter.

# **2.2** Classification of integral equations

The linearity of the IE depends on the power of the function  $\phi(x)$  as we have seen in the ordinary and partial differential equations. In this text, we shall distinguish three major types of integral equations. In particular, these types are given below:

1. Fredholm integral equations

$$r(x)\phi(x) = f(x) + \lambda \int_a^b K(x,y)\mathcal{N}_0(\phi(y))dy. \tag{2.2}$$

2. Volterra integral equations

$$r(x)\phi(x) = f(x) + \lambda \int_{a}^{x} K(x,y)\mathcal{N}_{0}(\phi(y))dy.$$
(2.3)

3. Mixed integral equations

$$r(x)\phi(x,t) = f(x,t) + \lambda \int_0^t \int_a^b F(t,\tau)K(x,y)\mathcal{N}_1(\phi(y,\tau))dyd\tau.$$
(2.4)

Or

$$r(x)\phi(x,t) = f(x,t) + \lambda \int_{a}^{b} K(x,y)\mathcal{N}_{2}(\phi(y,t))dy + \lambda \int_{0}^{t} F(t,\tau)\mathcal{N}_{3}(\phi(x,\tau))d\tau,$$

$$(2.5)$$

And the two well known types

- 1. Integro-differential equations
- 2. Fractional Partial Integro-differential equations

There are various forms of nonlinear integral equations [58] as follows:

Urysohn-second kind ϕ(t) = f(t) + R <sup>b</sup> a K(t, s, ϕ(s))ds

Hammerstein ϕ(t) = f(t) + R <sup>b</sup> a K(t, s)f(s, ϕ(s))ds

Urysohn-Volterra ϕ(t) = f(t) + R <sup>t</sup> a K(t, s, ϕ(s))ds

Hammerstein-Volterra-second kind ϕ(t) = f(t) + R <sup>t</sup>

a K(t, s)N (s, ϕ(s))ds

Hammerstein-Volterra-first kind R <sup>t</sup>

a K(t, s)N (s, ϕ(s))ds = f(t)

Chandrasekhar-H equation 1 + λ

R b a [tϕ(t)ϕ(s)/(t + s)]ds = f(t)

Cauchy singular a(t)ϕ(t) + b(t) R Γ [ϕ(s)/(s − t)]ds

$$+\int_{\Gamma} K(t,s,\phi(s))ds = f(t)$$

Γ = open or closed arc in R<sup>2</sup>

# <span id="page-6-0"></span>2.3 The relation between initial and boundary value problems with IEs

It is important to point out how to convert the initial (boundary) value problems to Volterra (Fredholm) integral equations and vice versa [68, 8]. The following two theorems are needed while converting between these types of equations.

#### Theorem 2.1. Leibnitz rule [8]

Assume that f(s,t) and its derivative  $\frac{\partial f}{\partial t}$  are continuous in a domain on the plane st where  $A(s) \leq s \leq B(s)$  and  $t_0 \leq t \leq t_1$ . If

<span id="page-6-1"></span>
$$\phi(s) = \int_{A(s)}^{B(s)} f(s,t)dt,$$
(2.6)

then the differentiation of Eq.(2.6) is given by

<span id="page-6-4"></span>
$$\frac{d\phi(s)}{ds} = \int_{A(s)}^{B(s)} \frac{\partial f(s,t)}{\partial s} dt + f(s,B(s)) \frac{dB}{ds} - f(s,A(s)) \frac{dA}{ds}.$$
(2.7)

**Theorem 2.2.** The general formula that converts multiple integrals to a single integral is given in [8] by

<span id="page-6-2"></span>
$$\int_{a}^{x} \int_{a}^{x_{1}} \cdots \int_{a}^{x_{n-1}} u(x_{n}) dx_{n} dx_{n-1} \cdots dx_{1} = \frac{1}{(n-1)!} \int_{a}^{x} (x-t)^{n-1} u(t) dt$$
(2.8)

where n is positive integer.

Next, we proceed how to convert IVPs to VIEs and vice versa

## **Converting IVPs to VIEs** [68, 8]

Consider the following IVP

<span id="page-6-3"></span>
$$y''(x) + p(x)y'(x) + q(x)y(x) = h(x), (2.9)$$

with the initial conditions y(0) = α and y ′ (0) = β where α and β are constants. Suppose

<span id="page-7-0"></span>
$$y''(x) = \phi(x), \tag{2.10}$$

integrating Eq.[\(2.10\)](#page-7-0) on [0, x] and using the initial conditions, we get

<span id="page-7-1"></span>
$$y'(x) = \beta + \int_{0}^{x} \phi(t)dt. \tag{2.11}$$

Similarly, integrating Eq.[\(2.11\)](#page-7-1) on [0, x] with the help of the initial conditions and Eq.[\(2.8\)](#page-6-2), we obtain

<span id="page-7-2"></span>
$$y(x) = \alpha + \beta x + \int_{0}^{x} (x - t)\phi(t)dt.$$
(2.12)

Substituting from Eqs.[\(2.10\)](#page-7-0), [\(2.11\)](#page-7-1) and [\(2.12\)](#page-7-2) for Eq.[\(2.9\)](#page-6-3), we get

<span id="page-7-3"></span>
$$\phi(x) = h(x) - \beta p(x) - \alpha g(x) - \beta x g(x) - \int_{0}^{x} [p(x) + g(x)(x - t)]\phi(t)dt. \quad (2.13)$$

Let f(x) = h(x)−βp(x)−(α +xβ)g(x) and K(x, t) = p(x) + g(x)(x−t), then Eq.[\(2.13\)](#page-7-3) can be written in the form

$$\phi(x) = f(x) - \int_{0}^{x} K(x,t)\phi(t)dt$$
(2.14)

which represents VIE of the second kind.

# Converting VIEs to IVPs[\[68,](#page-47-0) [8\]](#page-42-2)

Consider the following VIE of the second kind

<span id="page-7-4"></span>
$$\phi(x) = f(x) + \int_{0}^{x} K(x,t)\phi(t)dt$$
(2.15)

where

$$f(x) = h(x) - \beta p(x) - (\alpha + x\beta)g(x) \text{ and } K(x,t) = p(x) + g(x)(x-t).$$

Let p(x) = λ<sup>1</sup> and g(x) = λ<sup>2</sup> where λ<sup>1</sup> and λ<sup>2</sup> are constants, Eq.[\(2.15\)](#page-7-4) becomes

<span id="page-8-0"></span>
$$\phi(x) = f(x) + \lambda_1 \int_0^x \phi(t)dt + \lambda_2 \int_0^x (x - t)\phi(t)dt.$$
(2.16)

Differentiating Eq.[\(2.16\)](#page-8-0) with respect to x and using Eq.[\(2.7\)](#page-6-4), we get

<span id="page-8-1"></span>
$$\phi'(x) = f'(x) + \lambda_1 \phi(x) + \lambda_2 \int_0^x \phi(t) dt.$$
(2.17)

Similarity, differentiating Eq.[\(2.17\)](#page-8-1) with respect to x and using Leibnitz rule, we obtain

<span id="page-8-2"></span>
$$\phi''(x) = f''(x) + \lambda_1 \phi'(x) + \lambda_2 \phi(x). \tag{2.18}$$

Eq.[\(2.18\)](#page-8-2) represents ODE of the second order.

Putting x = 0 in Eq.[\(2.16\)](#page-8-0) and Eq.[\(2.17\)](#page-8-1), we get the initial conditions

<span id="page-8-3"></span>
$$\phi(0) = f(0), \qquad \phi'(0) = f'(0) + \lambda_1 f(0). \tag{2.19}$$

Therefore, Eq.[\(2.18\)](#page-8-2) with the conditions [\(2.19\)](#page-8-3) represents an IVP converted from the VIE [\(2.15\)](#page-7-4).

Now, we present examples of the converting process from BVPs to FIEs and vice versa.

# Converting BVPs to FIEs[\[68,](#page-47-0) [8\]](#page-42-2)

Consider the following BVP

<span id="page-8-5"></span>
$$y''(x) + g_1(x)y'(x) + g_2(x)y(x) = H(f(x), y(x)),$$
(2.20)

with the boundary conditions y(0) = α, y(1) = β. Let

<span id="page-8-4"></span>
$$y''(x) = \phi(x). \tag{2.21}$$

Integrating Eq.[\(2.21\)](#page-8-4) two times on [0, x] and using the boundary conditions, we obtain x x

<span id="page-9-0"></span>
$$\int_{0}^{x} y''(t)dt = \int_{0}^{x} \phi(t)dt$$
(2.22)

Eq.[\(2.22\)](#page-9-0) can be expressed as

<span id="page-9-1"></span>
$$y'(x) = y'(0) + \int_{0}^{x} \phi(t)dt.$$
(2.23)

Integrating Eq.[\(2.23\)](#page-9-1) on [0, x], using Eq.[\(2.8\)](#page-6-2) and boundary conditions, yield

<span id="page-9-3"></span>
$$y(x) = \alpha + xy'(0) + \int_{0}^{x} (x - t)\phi(t)dt.$$
(2.24)

Since y(1) = β, we get

<span id="page-9-2"></span>
$$y'(0) = \beta - \alpha - \int_{0}^{1} (1 - t)\phi(t)dt.$$
(2.25)

So, Eq.[\(2.23\)](#page-9-1) becomes

<span id="page-9-4"></span>
$$y'(x) = \beta - \alpha - \int_{0}^{1} (1 - t)\phi(t)dt + \int_{0}^{x} \phi(t)dt.$$
(2.26)

Substituting from Eq.[\(2.25\)](#page-9-2) and Eq.[\(2.24\)](#page-9-3) yields

<span id="page-9-5"></span>
$$y(x) = \alpha + x(\beta - \alpha) - \int_{0}^{1} x(1 - t)\phi(t)dt) + \int_{0}^{x} (x - t)\phi(t)dt.$$
(2.27)

Substituting from Eqs.(2.21), (2.26) and (2.27), thus Eq.(2.20) becomes

<span id="page-10-0"></span>
$$\phi(x) = \tilde{H}(x) - g_1(x) \left[ \beta - \alpha - \int_0^1 (1 - t)\phi(t)dt + \int_0^x \phi(t)dt \right] - g_2(x) \left[ \alpha + x(\beta - \alpha) - \int_0^1 x(1 - t)\phi(t)dt \right] + \int_0^x (x - t)\phi(t)dt \right],$$
(2.28)

where  $\tilde{H}(x) = H\left(f(x), \alpha + x(\beta - \alpha) - \int\limits_0^1 x(1-t)\phi(t)dt + \int\limits_0^x (x-t)\phi(t)dt\right)$ . Eq.(2.28) can be simplified as

<span id="page-10-1"></span>
$$\phi(x) = \tilde{H}(x) + g_1(x)(\alpha - \beta) - g_2(x)(\alpha + x(\beta - \alpha))$$

$$+ \int_0^1 (g_1(x) + xg_2(x))(1 - t)\phi(t)dt - \int_0^x (g_1(x) + (x - t)g_2(x))\phi(t)dt.$$
(2.29)

Partitioning of [0,1] to [0,x] and [x,1], we find that Dividing integration in Eq.(2.29) from 0 to 1, we get

<span id="page-10-2"></span>
$$\phi(x) = \tilde{H}(x) + g_1(x)(\alpha - \beta) - g_2(x)(\alpha + x(\beta - \alpha))$$

$$+ \int_0^x (g_1(x) + g_2(x))(1 - t)\phi(t)dt$$

$$+ \int_x^1 (g_1(x) + g_2(x))(1 - t)\phi(t)dt$$

$$- \int_0^x (g_1(x) + (x - t)g_2(x))\phi(t)dt.$$
(2.30)

<span id="page-11-0"></span>Eq.[\(2.30\)](#page-10-2) can be written in the form

$$\phi(x) = \tilde{H}(x) + g_1(x)(\alpha - \beta) - g_2(x)(\alpha + x(\beta - \alpha))$$

$$+ \int_0^x t(g_2(x)(1 - x) - g_1(x))\phi(t)dt$$

$$+ \int_x^1 (g_1(x) + xg_2(x))(1 - t)\phi(t)dt.$$
(2.31)

Let
$$\tilde{f}(x) = \tilde{H}(x) + g_1(x)(\alpha - \beta) - g_2(x)(\alpha + x(\beta - \alpha))$$
and  $K(x,t) = \begin{cases} t(g_2(x)(1-x) - g_1(x)), & \text{for } 0 \leqslant t \leqslant x \\ (g_1(x) + xg_2(x))(1-t), & \text{for } x \leqslant t \leqslant 1 \end{cases}$ .

Eq.[\(2.31\)](#page-11-0) can be written in the form

$$\phi(x) = \tilde{f}(x) + \int_{0}^{1} K(x, t)\phi(t)dt,$$
(2.32)

which represents FIE of the second kind.

# Converting FIEs to BVPs[\[68,](#page-47-0) [8\]](#page-42-2)

Consider the following FIE of the second kind

<span id="page-11-1"></span>
$$\phi(x) = \tilde{f}(x) + \int_{0}^{1} K(x, t)\phi(t)dt,$$
(2.33)

.

where ˜f(x) = H˜ (x) + g1(x)(α − β) − g2(x)(α + x(β − α)) and

$$K(x,t) = \begin{cases} t(g_2(x)(1-x) - g_1(x)), & 0 \le t \le x \\ (g_1(x) + xg_2(x))(1-t), & x \le t \le 1 \end{cases}$$

<span id="page-12-0"></span>Partitioning the integral in Eq.[\(2.33\)](#page-11-1) yield

$$\phi(x) = \tilde{f}(x) + \int_{0}^{x} t(g_{2}(x)(1-x) - g_{1}(x))\phi(t)dt$$

$$+ \int_{x}^{1} (g_{1}(x) + xg_{2}(x))(1-t)\phi(t)dt.$$
(2.34)

From Eq.[\(2.7\)](#page-6-4), we get

<span id="page-12-1"></span>
$$\frac{d}{dx} \int_{0}^{x} t(g_{2}(x)(1-x) - g_{1}(x))\phi(t)dt = x((1-x)g_{2}(x) - g_{1}(x))\phi(x)
+ \int_{0}^{x} t((1-x)g_{2}'(x) - g_{2}(x) - g_{1}'(x))\phi(t)dt$$
(2.35)

and

<span id="page-12-2"></span>
$$\frac{d}{dx} \int_{x}^{1} (g_1(x) + xg_2(x))(1-t)\phi(t)dt = (g_1(x) + xg_2(x))(x-1)\phi(x)
+ \int_{x}^{1} (g'_1(x) + g_2(x) + xg'_2(x))(1-t)\phi(t)dt.$$
(2.36)

<span id="page-12-3"></span>Differentiating Eq.[\(2.34\)](#page-12-0) with respect to x, using Eqs.[\(2.35\)](#page-12-1) and [\(2.36\)](#page-12-2), we obtain

$$\phi'(x) = \tilde{f}'(x) - g_1(x)\phi(x)$$

$$+ \int_0^x t((1-x)g_2'(x) - g_2(x) - g_1'(x))\phi(t)dt$$

$$+ \int_x^1 (g_1'(x) + g_2(x) + xg_2'(x))(1-t)\phi(t)dt.$$
(2.37)

Using Eq.[\(2.7\)](#page-6-4), we have

<span id="page-13-0"></span>
$$\frac{d}{dx} \int_{0}^{x} t((1-x)g_{2}'(x) - g_{2}(x) - g_{1}'(x))\phi(t)dt$$

$$= x((1-x)g_{2}'(x) - g_{2}(x) - g_{1}'(x))\phi(x)$$

$$+ \int_{0}^{x} t((1-x)g_{2}''(x) - 2g_{2}'(x) - g_{1}''(x))\phi(t)dt$$
(2.38)

and

<span id="page-13-1"></span>
$$\frac{d}{dx} \int_{x}^{1} (g_{1}'(x) + g_{2}(x) + xg_{2}'(x))(1 - t)\phi(t)dt$$

$$= -(g_{1}'(x) + g_{2}(x) + xg_{2}'(x))(1 - x)\phi(x)$$

$$+ \int_{x}^{1} (g_{1}''(x) + 2g_{2}'(x) + xg_{2}''(x))(1 - t)\phi(t)dt.$$
(2.39)

Differentiating both sides of Eq.[\(2.37\)](#page-12-3) with respect to x with the help of Eqs.[\(2.38\)](#page-13-0) and [\(2.39\)](#page-13-1), we obtain

$$\phi''(x) = f''(x) - \lambda x \phi(x) + \lambda (1 - x)\phi(x), \tag{2.40}$$

Differentiating Eq.[\(2.34\)](#page-12-0) two times with respect to x with the help of [\(2.7\)](#page-6-4), we obtain and [\(2.8\)](#page-6-2), we obtain

<span id="page-13-2"></span>
$$\phi''(x) = \tilde{f}''(x) - g_1(x)\phi'(x) - (2g_1'(x) + g_2(x))\phi(x)$$

$$+ \int_0^x t((1-x)g_2''(x) - 2g_2'(x) - g_1''(x))\phi(t)dt$$

$$+ \int_x^1 (g_1''(x) + 2g_2'(x) + xg_2''(x))(1-t)\phi(t)dt.$$
(2.41)

<span id="page-14-1"></span>For simplicity, let g1(x) = 0 and g2(x) = λ. So, Eq.[\(2.41\)](#page-13-2) becomes

$$\phi''(x) + \lambda \phi(x) = \tilde{f}''(x). \tag{2.42}$$

To determine the boundary conditions, subistitute by x = 0 and x = 1 in Eq.[\(2.34\)](#page-12-0), we find

<span id="page-14-2"></span>
$$\phi(0) = \tilde{f}(0) \text{ and } \phi(1) = \tilde{f}(1).$$
(2.43)

<span id="page-14-0"></span>Therefore, Eq.[\(2.42\)](#page-14-1) with conditions [\(2.43\)](#page-14-2) represents BVP which converted from FIE [\(2.33\)](#page-11-1).

# 2.4 Existence and uniqueness theorems

In this section, we present some properties of a class of contraction operators in addition to number of basic existence and uniqueness theorems for integral equations.

#### Definition 2.1. Contraction operator [\[16\]](#page-43-0)

Let H be a Hilbert space and T a bounded operator on H. T is not necessarily a linear operator. T is said to be a contraction operator if there exists a positive constant 0 ≤ α < 1 such that for all f1, f<sup>2</sup> in H.

$$||Tf_1 - Tf_2|| \le \alpha ||f_1 - f_2||$$

# Definition 2.2. Fixed point [\[16\]](#page-43-0)

Let X be a non-empty set and T : X → X a mapping, a fixed point of the mapping T is a point x ∈ X such that T x = x. In other words, a fixed point of T is a solution for the IE ( T x = x) ∀ x ∈ X.

## Theorem 2.3. *Banach fixed point theorem [\[16\]](#page-43-0).*

*Let* H *be a Hilbert space and* T *be a contraction operator on* H*. The equation*

<span id="page-14-3"></span>
$$Tf = f (2.44)$$

*has a unique solution* f *in* H*. Such a solution is said to be a fixed point of* T*.*

*Proof.* Assume there are two fixed points f and g therefore

$$Tf = f,$$

$$Tg = g$$
.

Subsequently

$$||f - g|| = ||Tf - Tg|| \le \alpha ||f - g||$$

and

$$(1-\alpha)\|f-g\| \le 0.$$

Since ∥f − g∥ ≥ 0 and 1 − α < 0, we get

$$||f - g|| = 0,$$

so f = g. It follows that the solution of Eq.[\(2.44\)](#page-14-3) is unique.

To show that {fn} has a solution, we shall set up an iteration procedure. Select any f<sup>0</sup> and then construct a sequence {fn} defined by

$$f_{n+1} = Tf_n, \quad n = 0, 1, 2, \dots$$

Firstly, we shall show that {fn} is a Cauchy sequence, and then that its limit is indeed a solution of Eq.[\(2.44\)](#page-14-3). That it has a limit will follow from the fact that a Cauchy sequence must have a unique limit in a Hilbert space. The limit will be independent of the initial choice f0, since it will be a solution of Eq.[\(2.44\)](#page-14-3), which must be unique. Now, we note

$$||f_{n+1} - f_n|| = ||Tf_n - Tf_{n-1}|| \le \alpha ||f_n - f_{n-1}||.$$
(2.45)

<span id="page-15-0"></span>From Eq.[\(2.45\)](#page-15-0), we have

$$||f_{n+1} - f_n|| \le \alpha ||f_n - f_{n-1}|| \le \alpha^2 ||f_{n-1} - f_{n-2}|| \le \dots \le \alpha^n ||f_1 - f_0||.$$

For n > m, we get

$$||f_{n} - f_{m}|| = ||(f_{n} - f_{n-1}) + (f_{n-1} - f_{n-2}) + \dots + (f_{m+1} - f_{m})||$$

$$\leq ||f_{n} - f_{n-1}|| + ||f_{n-1} - f_{n-2}|| + \dots + ||f_{m+1} - f_{m}||$$

$$\leq (\alpha^{n-1} + \alpha^{n-2} + \dots + \alpha^{m}) ||f_{1} - f_{0}||$$

$$\leq (\alpha^{m} + \alpha^{m+2} + \dots) ||f_{1} - f_{0}|| = \frac{\alpha^{m}}{1 - \alpha} ||f_{1} - f_{0}||$$

so that

$$\lim_{n,m\to\infty} \|f_n - f_m\| = 0$$

It follows that {fn} is Cauchy sequence and its limit is denoted by f.

### <span id="page-16-0"></span>Theorem 2.4. *[\[27\]](#page-44-1)*

*Let* T *be an operator on* H*, such that the* n th *power of* T*, namely* T n *is a contraction operator, then the equation*

$$Tf = f$$

*has a unique solution* f *in* H*.*

*Proof.* Using Theorem [\(2.4\)](#page-16-0), we have

$$T^n f = f (2.46)$$

has a unique solution. Actually, we can obtain the solution by finding

$$\lim_{k \to \infty} T^{kn} f_0 = f,$$

for an arbitrary initial function f0. In particular, let f<sup>0</sup> = T f, we get

$$\lim_{k \to \infty} T^{kn} T f = f.$$

But since T n f = f, we also have T knf = f so that limk→∞ T knT f = limk→∞ T Tknf = limk→∞ T f = T f.

To show that this solution is unique, we note that if

$$Tf = f$$
,  $Tq = q$ ,

we have

$$T^n f = f$$
,  $T^n g = g$

and since  $T^n$  is a contraction operator with a unique fixed point f = g.

## An existence theorem for nonlinear Fredholm integral equations[27]

#### **Theorem 2.5.** [27]

Consider the following nonlinear Fedholm integral equation

<span id="page-17-0"></span>
$$\phi(x) - \lambda \int_a^b K(x, y, \phi(y)) dy = f(x), \qquad (2.47)$$

satisfies

$$\left\| \int_{a}^{b} K(x, y, \phi(y)) dy \right\| \le M \|\phi(y)\|$$

and

$$|K(x, y, \phi_1(y)) - K(x, y, \phi_2(y))| \le N(x, y) |\phi_1(y) - \phi_2(y)|,$$

where

$$\int_a^b \int_a^b |N(x,y)|^2 dx dy = P^2 < \infty.$$

If the function  $f(x) \in L_2[a,b]$  and  $|\lambda|P < 1$ , then Eq (2.47) has a unique solution.

## An existence theorem for nonlinear Volterra integral equations[?]

## **Theorem 2.6.** [8]

Suppose the following nonlinear Volterra integral equation

<span id="page-17-1"></span>
$$\phi(x) + \int_{a}^{x} K(x, y, \phi(y)) dy = f(x), \tag{2.48}$$

satisfies the following assumptions:

2.5. Kernels of IEs 18

*i. the function* f(x) *is bounded and satisfies Lipschitz condition, i.e.* |f(x)| < f*, in the interval* a ≤ x ≤ b *and satisfies Lipschitz condition:*

$$|f(x_1) - f(x_2)| < l|x_1 - x_2| \quad x_1, x_2 \in (a, b).$$
(2.49)

*ii. the function* K(x, y, ϕ(y)) *is integrable and bounded,*

$$|K(x, y, \phi(y))| < K, \qquad a \le x, y \le b.$$

*and*

*iii. the function* K(x, y, ϕ(x)) *satisfies Lipschitz condition, such that:*

$$|K(x, y, \phi_1(y)) - K(x, y, \phi_2(y))| < M |\phi_1(y) - \phi_2(y)|$$
(2.50)

*then Eq.[\(2.48\)](#page-17-1) has a unique solution.*

# <span id="page-18-0"></span>2.5 Kernels of IEs

We have two types of kernels; continuous and discontinuous kernels.

# 1. Degenerate kernel

The kernel k(x, t) of IE is called degenerate kernel if it is a sum of finite number of product functions of x only and t only

$$k(x,t) = \sum_{i=1}^{n} a_i(x)b_i(t)$$

where ai(x) and bi(t) are sets of linearly independent functions.

#### 2. Resolvent kernel

The resolvent kernel R(x, t; λ) are defined as

$$R(x,t;\lambda) = \frac{D(x,t;\lambda)}{\Delta(\lambda)}$$

2.5. Kernels of IEs 19

where
$$D(x, t; \lambda) = \sum_{n=1}^{\infty} \lambda^{n-1} k_n(x, t), \Delta(\lambda) = 1 + \sum_{n=1}^{\infty} c_n \lambda^n,$$

$k_n(x, t) = \int_a^b k_{n-1}(x, s) k(s, t) ds$  and  $k_1(x, t) = k(x, t).$

#### 3. Iterated kernel

The iterated kernels kn(x, t), n = 1, 2, 3, · · · are defined as

$$k_n(x,t) = \int_a^b k(x,z)k_{n-1}(x,t)dt, \ k_0(x,t) = k(x,t).$$

#### 4. Symmetric kernel

A kernel k(x, t) is called symmetric (Hermitian) if

$$k(s,t) = k^*(t,s)$$

where k ∗ (t, s) denotes the complex conjugate.

#### 5. Orthogonal kernels

Assume that two kernels k(x, t) and L(x, t) are given, these kernels are said to be orthogonal if the following two conditions

$$\int\limits_a^b k(x,z)L(z,t)dz=0 \text{ and } \int\limits_a^b L(x,z)k(z,t)dz=0,$$

<span id="page-19-0"></span>for all values of x and t are satisfied.

# 2.5.1 (discontinuous) kernels

A singular kernel is a kernel that has an infinite discontinuity in the interior of the interval of integration or at a boundary point of it. The singular kernel may take one of the following forms:

#### 1. Cauchy kernel

If the kernel k(x, t) of IE takes the form

$$k(x,t) = \frac{A(x,t)}{x-t}$$

where A(x, t) ̸= 0 is a differentiable function of x and t.

#### 2. Abel's kernel

If the kernel k(x, t) of IE takes the form

$$k(x,t) = \frac{A(x,t)}{(x-t)^n}, \quad 0 < n < 1.$$

The IE is called a singular IE with Abel's kernel.

#### 3. Carleman kernel

If the kernel k(x, t) of IE takes the form

$$k(x,t) = \frac{A(x,t)}{|x-t|^n}, \quad 0 < n < 1.$$

The IE is called a singular IE with Carleman kernel.

#### 4. Logarithmic kernel

If the kernel k(x, t) of IE takes the form

$$k(x,t) = A(x,t) \ln |x-t|.$$

The IE is called a singular IE with logarithmic kernel.

# <span id="page-20-0"></span>2.6 Analytical methods for solving IEs with continuous kernel

Now, we are going to discuss some analytical methods [68, ?, ?] which depend on the form of kernel of IEs; we can use the DKM if the kernel is continuous and can be written as multiplication of two functions. Otherwise, we can use the SAM. When the kernel is in the form k(x - t), we can use Laplace transformation and convolution theorem to solve IEs.

## <span id="page-20-1"></span>2.6.1 **Degenerate kernel method**

Consider the following FIE of the second kind

<span id="page-20-2"></span>
$$\phi(x) = f(x) + \lambda \int_{a}^{b} k(x, t)\phi(t)dt.$$
(2.51)

Assume that the kernel k(x, t) ∈ L2([a, b] × [a, b]) and is bounded such that

<span id="page-21-0"></span>
$$k(x,t) = \sum_{i=1}^{n} a_i(x)b_i(t).$$
(2.52)

Substituting from Eq.[\(2.52\)](#page-21-0) in Eq.[\(2.51\)](#page-20-2) and interchanging the order of integration and summation, we get

<span id="page-21-2"></span>
$$\phi(x) = f(x) + \lambda \sum_{i=1}^{n} a_i(x) \int_{a}^{b} b_i(t)\phi(t)dt.$$
(2.53)

<span id="page-21-1"></span>Let
$$c_i = \int_a^b b_i(t)\phi(t)dt, \quad 1 \le i \le n$$
(2.54)

where c<sup>i</sup> are arbitrary constants. Substituting from Eq.[\(2.54\)](#page-21-1) in Eq.[\(2.53\)](#page-21-2) yields

<span id="page-21-3"></span>
$$\phi(x) = f(x) + \lambda \sum_{i=1}^{n} a_i(x)c_i.$$
(2.55)

Substituting from [\(2.55\)](#page-21-3) in [\(2.54\)](#page-21-1), we get

$$c_{i} = \int_{a}^{b} b_{i}(t) \left[ f(t) + \lambda \sum_{j=1}^{n} a_{j}(t) c_{j} \right] dt.$$
(2.56)

<span id="page-21-4"></span>
$$c_{i} - \lambda \sum_{j=1}^{n} c_{j} \int_{a}^{b} a_{j}(t)b_{i}(t)dt = \int_{a}^{b} b_{i}(t)f(t)dt,$$
(2.57)

<span id="page-21-6"></span>Let
$$A_{ij} = \int_{a}^{b} a_j(t)b_i(t)dt$$
and  $B_i = \int_{a}^{b} b_i(t)f(t)dt$ , (2.58)

then Eq.[\(2.57\)](#page-21-4) can be represented in the form

<span id="page-21-5"></span>
$$c_i - \lambda \sum_{j=1}^n c_j A_{ij} = B_i, \qquad 1 \le i \le n.$$
(2.59)

The system (2.59) represents an algebraic system of n unknown constants  $c_1, c_2, ..., c_n$ . Finding the solution of FIE (2.51) with DKM is equivalent to find the solution of the system (2.59)

<span id="page-22-0"></span>
$$(I - \lambda A)C = B \tag{2.60}$$

where

$$A = \begin{pmatrix} A_{11} & A_{12} & \dots & A_{1n} \\ A_{21} & A_{22} & \dots & A_{2n} \\ \vdots & & & & \\ A_{n1} & A_{n2} & \dots & A_{nn} \end{pmatrix}, \quad C = \begin{bmatrix} c_1 \\ c_2 \\ \vdots \\ c_n \end{bmatrix} and \quad B = \begin{bmatrix} B_1 \\ B_2 \\ \vdots \\ B_n \end{bmatrix}. \quad (2.61)$$

The system (2.60) has a unique solution if  $Det(I - \lambda A) \neq 0$  and either no solution or infinite solutions if  $Det(I - \lambda A) = 0$ . After we calculate the unknown constants  $c_1, c_2, ..., c_n$ , we substitute in (2.55) which represents the solution of FIE (2.51) of the second kind.

#### **Example 2.7.** Solve the following FIE of the second kind using DKM

$$\phi(x) = 4x + \int_{0}^{1} (x \ln t - t \ln x)\phi(t)dt.$$
(2.62)

**Solution** From Eq.(2.52), we get  $a_1(x) = x$ ,  $a_2(x) = \ln x$ ,  $b_1(t) = \ln t$  and  $b_2(t) = -t$ . Eq.(2.58) yields

<span id="page-22-1"></span>
$$A_{11} = -\frac{1}{4}, A_{12} = 2, A_{21} = -\frac{1}{3}, A_{22} = \frac{1}{4}, B_1 = -1 \text{ and } B_2 = -\frac{4}{3}.$$
(2.63)

Since
$$Det(I - \lambda A) = \frac{7}{48} \neq 0,$$
(2.64)

the system (2.60) has a unique solution. Substituting from Eq.(2.63)in Eq.(2.60) yields

<span id="page-22-2"></span>
$$\begin{pmatrix} -\frac{1}{4} & 2\\ -\frac{1}{3} & \frac{1}{4} \end{pmatrix} \begin{pmatrix} c_1\\ c_2 \end{pmatrix} = \begin{pmatrix} -1\\ -\frac{4}{3} \end{pmatrix}. \tag{2.65}$$

The solution of the system (2.65) is

<span id="page-23-1"></span>
$$\begin{pmatrix} c_1 \\ c_2 \end{pmatrix} = \begin{pmatrix} -\frac{164}{77} \\ -\frac{64}{77} \end{pmatrix}. \tag{2.66}$$

Substituting from Eq.(2.66) in Eq.(2.55) yields

$$\phi(x) = 4x + \sum_{i=1}^{2} a_i(x)c_i$$

$$= 4x + x(\frac{-164}{77}) + \ln x(-\frac{64}{77}) = \frac{144}{77}x - \frac{64}{77}\ln x.$$
(2.67)

#### <span id="page-23-2"></span>**Theorem 2.8.** [?]

If f(x) in the recurrence relation

$$\phi_n(x) = f(x) + \lambda \int_0^x K(x, t)\phi_{n-1}(t)dt, \quad n \geqslant 1$$
(2.68)

in the interval  $0 \le x \le a$  and the kernel K(x,t) in the triangle  $0 \le x \le a$  and  $0 \le t \le a$  are continuous, then the sequence of successive approximations  $\phi_n(x), n \ge 0$  converges to the solution  $\phi(x)$  of IE under discussion.

# <span id="page-23-0"></span>2.6.2 **Successive approximation method**[?]

We are going to introduce the SAM for solving FIEs of the second kind. The SAM is called Picard's iteration method. Using this method depends on finding the successive approximations to the solution starting with an initial guess wich is called the zeroth approximation. Moreover, the zeroth approximation is any selective real-valued function that will be used in a recurrence relation to determine other approximations.

Assume that f(x) and the kernel k(x,t) are continuous in the interval [a,b] in Eq.(2.51) and choose continuous function which is called the zeroth approxima-

tion ϕ0(x) = f(x). The SAM introduces the recurrence relation

<span id="page-24-1"></span>
$$\phi_{n+1}(x) = f(x) + \lambda \int_{a}^{b} k(x,t)\phi_n(t)dt.$$
(2.69)

Several successive approximations will be determined as

<span id="page-24-0"></span>
$$\phi_1(x) = f(x) + \lambda \int_a^b k(x, t)\phi_0(t)dt.$$
(2.70)

Using Eq.[\(2.70\)](#page-24-0), Eq.[\(2.69\)](#page-24-1) yields the second-order approximation

$$\phi_2(x) = f(x) + \lambda \int_a^b k(x, t)\phi_1(t)dt.$$
(2.71)

Continuing the process, we obtain

<span id="page-24-3"></span>
$$\phi_n(x) = f(x) + \lambda \int_a^b k(x, t) \phi_{n-1}(t) dt.$$
(2.72)

Using theorem [\(2.8\)](#page-23-2) and definition of convergence, the solution of the IE is determined by using a limit of iterations as

<span id="page-24-2"></span>
$$\phi(x) = \lim_{n \to \infty} \phi_n(x). \tag{2.73}$$

Eq.[\(2.73\)](#page-24-2) represents the solution of FIE [\(2.51\)](#page-20-2), using SAM.

Example 2.9. Using SAM to solve the following FIE of the second kind

<span id="page-24-4"></span>
$$\phi(x) = e^x + \frac{1}{e} \int_0^1 \phi(t)dt.$$
(2.74)

Solution Let ϕ0(x) = f(x) = e x and substituting in Eq.[\(2.72\)](#page-24-3), we obtain

$$\phi_1(x) = e^x + 1 - \frac{1}{e}, \quad \phi_2(x) = e^x + 1 - \frac{1}{e^2},$$

$$\phi_3(x) = e^x + 1 - \frac{1}{e^3} \text{ and } \phi_n(x) = e^x + 1 - \frac{1}{e^n}.$$
(2.75)

Therefore, the solution of Eq.[\(2.74\)](#page-24-4) is a limit of iterations s.t.

$$\phi(x) = \lim_{n \to \infty} \phi_n(x) = \lim_{n \to \infty} \{e^x + 1 - \frac{1}{e^n}\} = e^x + 1.$$
(2.76)

#### Theorem 2.10. *[*?*]*

*Let* λ *be a complex parameter and* f(x) *and* k(x, t) *a complex-valued continuous functions defined on the interval* [a, b] *with*

$$||k||_2 = \left(\int_a^b \int_a^b |k(x,t)|^2 dx dt\right)^{1/2}.$$
(2.77)

*If* |λ|∥k∥<sup>2</sup> < 1*, then the unique solution to the FIE of the second kind*

$$\phi(x) = f(x) + \lambda \int_{a}^{b} k(x, t)\phi(t)dt$$
(2.78)

*is given by*

$$\phi(x) = f(x) + \lambda \int_{a}^{b} R(x, t; \lambda) f(t) dt$$
(2.79)

*where* R(x, t; λ) *is the resolvent kernel*

$$R(x,t;\lambda) = \sum_{n=1}^{\infty} \lambda^{n-1} k_n(x,t)$$
(2.80)

<span id="page-25-0"></span>*where* kn(x, t) = R b a kn−1(x, s)k(s, t)ds*.*

# 2.6.3 Resolvent kernel method

Consider the VIE of the second kind

<span id="page-26-5"></span>
$$\phi(x) = f(x) + \lambda \int_{0}^{x} k(x,t)\phi(t)dt$$
(2.81)

where k(x, t) is continuous for 0 ≤ x ≤ a, 0 ≤ t ≤ x and f(x) is continuous for 0 ≤ x ≤ a. Let ϕ0(x) = f(x) and

<span id="page-26-1"></span>
$$\phi_n(x) = f(x) + \lambda \int_0^x k(x, t) \phi_{n-1}(t) dt,$$
(2.82)

we get

<span id="page-26-0"></span>
$$\phi_{n-1}(x) = f(x) + \lambda \int_{0}^{x} k(x,t)\phi_{n-2}(t)dt.$$
(2.83)

Subtracting Eq.[\(2.83\)](#page-26-0) from Eq.[\(2.82\)](#page-26-1) yields

<span id="page-26-3"></span>
$$\phi_n(x) - \phi_{n-1}(x) = \lambda \int_0^x k(x,t) [\phi_{n-1}(t) - \phi_{n-2}(t)] dt.$$
(2.84)

Assume that

<span id="page-26-2"></span>
$$\phi_n(x) - \phi_{n-1}(x) = \lambda^n \psi_n(t) \text{ and } \psi_0(x) = f(x),$$
(2.85)

substituting from Eq.[\(2.85\)](#page-26-2) in Eq.[\(2.84\)](#page-26-3) yields

<span id="page-26-4"></span>
$$\psi_n(x) = \int_0^x k(x, t)\psi_{n-1}(t)dt.$$
(2.86)

From Eq.[\(2.86\)](#page-26-4), we have

$$\psi_1(x) = \int_0^x k(x, t) f(t) dt$$
(2.87)

<span id="page-27-0"></span>and
$$\psi_2(x) = \int_0^x k(x,t)\psi_1(t)dt = \int_0^x k(x,t) \left[ \int_0^t k(x,\tau)f(\tau)d\tau \right] dt.$$
(2.88)

Since k(x, t) and f(x) are continuous, the order of integration in Eq.[\(2.88\)](#page-27-0) can be interchanged s.t.

$$\psi_2(x) = \int_0^x \int_\tau^x k(x,t)k(t,\tau)f(\tau)dtd\tau$$

$$= \int_0^x k_2(x,\tau)f(\tau)d\tau$$
(2.89)

where

$$k_2(x,\tau) = \int_{\tau}^{x} k(x,t)k(t,\tau)dt.$$
(2.90)

Similarly, we have

<span id="page-27-2"></span>
$$\psi_n(x) = \int_0^x k_n(x,t)f(t)dt$$
(2.91)

<span id="page-27-4"></span>where kn(x, t) are called iterative kernels and determine from the relation

$$k_n(x,t) = \int_{t}^{x} k(x,\tau)k_{n-1}(\tau,t)d\tau$$
, and  $k_1(x,t) = k(x,t)$ . (2.92)

<span id="page-27-1"></span>Eq.[\(2.85\)](#page-26-2) yields

$$\phi_{1}(x) = \psi_{0}(x) + \lambda \psi_{1}(x),$$

$$\phi_{2}(x) = \psi_{0}(x) + \lambda \psi_{1}(x) + \lambda^{2} \psi_{2}(x) \text{ and}$$

$$\phi_{3}(x) = \psi_{0}(x) + \lambda \psi_{1}(x) + \lambda^{2} \psi_{2}(x) + \lambda^{3} \psi_{3}(x).$$
(2.93)

From system [\(2.93\)](#page-27-1), we get

<span id="page-27-3"></span>
$$\phi_n(x) = \sum_{i=0}^n \lambda^i \psi_i(x). \tag{2.94}$$

<span id="page-28-0"></span>Substituting from Eq.[\(2.91\)](#page-27-2) in Eq.[\(2.94\)](#page-27-3), we obtain

$$\phi_n(x) = \psi_0(x) + \sum_{i=1}^n \lambda^i \psi_i(x)$$

$$= f(x) + \lambda \int_0^x \sum_{i=1}^n \lambda^{i-1} k_i(x,t) f(t) dt$$

$$= f(x) + \lambda \int_0^x R(x,t,\lambda) f(t) dt$$
(2.95)

where
$$R(x,t,\lambda) = \sum_{n=1}^{\infty} \lambda^{n-1} k_n(x,t). \tag{2.96}$$

Eq.[\(2.95\)](#page-28-0) represents the solution of VIE [\(2.81\)](#page-26-5) where the resolvent kernel is evaluated from Eq.[\(2.96\)](#page-28-1).

Example 2.11. Using the resolvent kernel method to solve the following VIE of the second kind

<span id="page-28-5"></span><span id="page-28-1"></span>
$$\phi(x) = e^x + \int_0^x e^{x-t} \phi(t) dt.$$
(2.97)

<span id="page-28-2"></span>Solution Assume that k(x, t) = k1(x, t) = e x−t , Eq.[\(2.92\)](#page-27-4) yields

$$k_{2}(x,t) = \int_{t}^{x} k(x,\tau)k_{1}(\tau,t)d\tau$$

$$= \int_{t}^{x} e^{x-t}d\tau = (x-t)e^{x-t}.$$
(2.98)

<span id="page-28-3"></span>Using the values of k1(x, t) and k2(x, t), we obtain

$$k_3(x,t) = \int_{t}^{x} k(x,\tau)k_2(\tau,t)d\tau = \frac{(x-t)^2}{2}e^{x-t}$$
and (2.99)

<span id="page-28-4"></span>
$$k_4(x,t) = \int_{t}^{x} k(x,\tau)k_3(\tau,t)d\tau = \frac{(x-t)^3}{6}e^{x-t}.$$
(2.100)

From Eq.[\(2.98\)](#page-28-2), Eq.[\(2.99\)](#page-28-3) and Eq.[\(2.100\)](#page-28-4), we get

$$k_n(x,t) = e^{x-t} + (x-t)e^{x-t} + \frac{(x-t)^2}{2}e^{x-t} + \frac{(x-t)^3}{6}e^{x-t} + \dots$$

$$= \frac{(x-t)^{n-1}}{(n-1)!}e^{x-t}.$$
(2.101)

<span id="page-29-0"></span>Eq.[\(2.96\)](#page-28-1) yields that the resolvent kernel is

$$R(x,t,\lambda) = k_1(x,t) + k_2(x,t) + k_3(x,t) + \dots$$

$$= \sum_{n=1}^{\infty} \frac{(x-t)^{n-1}}{(n-1)!} e^{x-t}$$

$$= e^{2(x-t)}.$$
(2.102)

Substituting from Eq.[\(2.102\)](#page-29-0) in Eq.[\(2.95\)](#page-28-0), the solution of Eq.[\(2.97\)](#page-28-5) is

$$\phi(x) = e^x + \int_0^x e^{2(x-t)}e^t dt = e^x + \int_0^x e^{2x-t} dt = e^{2x}.$$
(2.103)

#### Theorem 2.12. *Fredholm alternative theorem[*?*]*

<span id="page-29-1"></span>*If the homogeneous FIE of the second kind*

$$\phi(x) = \lambda \int_{a}^{b} k(x, t)\phi(t)dt$$
(2.104)

<span id="page-29-3"></span>*has unique solution* ϕ(x) = 0*, then the corresponding nonhomogeneous FIE*

$$\phi(x) = f(x) + \lambda \int_{a}^{b} k(x, t)\phi(t)dt$$
(2.105)

*has always a unique solution. The adjoint equation*

<span id="page-29-2"></span>
$$\psi(x) = \overline{\lambda} \int_{a}^{b} \overline{k(y,x)} \psi(y) dy$$
(2.106)

*has the same number of solutions of Eq.[\(2.104\)](#page-29-1). If the number of solutions of*

Eq.(2.104) and Eq.(2.106) is positive, then Eq.(2.105) will have a nonunique solution, iff

$$(f,\psi) = \int_a^b f(x)\overline{\psi(x)}dx = 0$$
(2.107)

for all solutions  $\psi(x)$  of Eq.(2.106)

#### **Example 2.13.** Consider the following FIE of the second kind

<span id="page-30-0"></span>
$$\phi(x) = f(x) + \lambda \int_0^1 \left[ \pi x \sin \pi t + 2\pi x^2 \sin 2\pi t \right] \phi(t) dt.$$
(2.108)

**Solution** Let

$$c_{1} = \int_{0}^{1} \sin \pi t \phi(t) dt, \qquad B_{1} = \int_{0}^{1} \sin \pi t f(t) dt$$

$$c_{2} = \int_{0}^{1} \sin 2\pi t \phi(t) dt \text{ and } B_{2} = \int_{0}^{1} \sin 2\pi t f(t) dt,$$
(2.109)

from the system (2.59), Eq.(2.108) can be reduced to

<span id="page-30-1"></span>
$$(1 - \lambda)c_1 - 2\left(1 - \frac{4}{\pi^2}\right)\lambda c_2 = B_1$$

$$\frac{\lambda}{2}c_1 + (1 - \lambda)c_2 = B_2$$
(2.110)

and from the systems (2.60) and (2.110), we get  $Det(I - \lambda A) = \lambda^2 - \pi^2/4$ . So, we have:

(i) If  $\lambda^2 \neq (\pi^2/4)$ , we get that the system (2.110) has a unique solution s.t.

$$c_{1} = \frac{(1+\lambda)B_{1} + 2\left[1 - \left(4/\pi^{2}\right)\right]\lambda B_{2}}{1 - (4\lambda^{2}/\pi^{2})} \text{ and}$$

$$c_{2} = \frac{(-\lambda/2)B_{1} + (1-\lambda)B_{2}}{1 - (4\lambda^{2}/\pi^{2})},$$
(2.111)

so the solution of the Eq.(2.108) is

$$\phi(x) = f(x) + \pi \lambda c_1 x + 2\pi \lambda c_2 x^2. \tag{2.112}$$

(ii) If λ = (π/2), we consider the adjoint system

$$\left(1 - \frac{\pi}{2}\right)\zeta_1 + \frac{\pi}{4}\zeta_2 = 0, \quad -\pi\left(1 - \frac{4}{\pi^2}\right)\zeta_1 + \left(1 + \frac{\pi}{2}\right)\zeta_2 = 0 \quad (2.113)$$

with solutions ζ<sup>1</sup> = (π/4)Λ and ζ<sup>2</sup> = −[1 − (π/2)]Λ where Λ is arbitrary. In order for a solution to exist, we require that

$$\frac{\pi}{4}B_1 - \left(1 - \frac{\pi}{2}\right)B_2 = 0.$$

If the above condition holds, we obtain

$$\phi(x) = f(x) + \frac{\pi}{2} \left\{ \frac{B_1}{1 - (\pi/2)} - 2\left(1 + \frac{2}{\pi}\right) \Lambda x + \pi \Lambda x^2 \right\}.$$
(2.114)

Since Λ is arbitrary, the nonunique solution exists.

# <span id="page-31-0"></span>2.6.4 Laplace Transformation Method

We are going to introduce LTM for solving VIEs of the second kind which be a powerful technique that can be used for solving IEs. We can use this method when the kernel k(x − t) of the IE is a function of the difference only, in this case the IE is called IE of convolution type.

## Definition 2.3. Laplace transform

Let f(x) be a function defined for 0 ≤ x < ∞, then the Laplace transform of f(x) is denoted by L{f(x);t} or F(t) and defined as

$$\mathcal{L}\{f(x);t\} = F(t) = \int_{0}^{\infty} e^{-tx} f(x) dx, \quad t > 0.$$
(2.115)

Laplace transform satisfies the linearity property.

If for i ∈ {1, 2, . . . , n}, c<sup>i</sup> are constants and fi(x) are functions with Laplace transforms Fi(t), then we have

$$\mathcal{L}\{c_1 f_1(x) + \dots + c_n f_n(x); p\} = c_1 \mathcal{L}\{f_1(x); p\} + \dots + c_n \mathcal{L}\{f_n(x); p\}$$

$$= c_1 F_1(p) + \dots + c_n F_n(p).$$
(2.116)

#### Theorem 2.14. *The convolution theorem*

*Let* f(x) *and* g(x) *be two functions with* L <sup>−</sup><sup>1</sup>{F(t); x} = f(x) *and* L <sup>−</sup><sup>1</sup>{G(t); x} = g(x)*, then we get*

$$\mathcal{L}\left\{\int_{0}^{x} f(u)g(x-u)du\right\} = \mathcal{L}\left\{\int_{0}^{x} f(x-u)g(u)du\right\}$$

$$= F(t)G(t).$$
(2.117)

Applying the convolution definition and Laplace transform to Eq.[\(2.81\)](#page-26-5) yield

<span id="page-32-1"></span>
$$\mathcal{L}\{\phi(x)\} = F(t) + \lambda K(t)\mathcal{L}\{\phi(x)\}. \tag{2.118}$$

Eq.[\(2.118\)](#page-32-1) can be written in the form

<span id="page-32-2"></span>
$$\mathcal{L}\{\phi(x)\} = \frac{F(t)}{1 - \lambda K(t)}.$$
(2.119)

Taking the inverse Laplace transform to Eq.[\(2.119\)](#page-32-2), we get

<span id="page-32-3"></span>
$$\phi(x) = \mathcal{L}^{-1} \{ \frac{F(t)}{1 - \lambda K(t)} \}. \tag{2.120}$$

Eq.[\(2.120\)](#page-32-3) represents the solution of VIE [\(2.81\)](#page-26-5).

Example 2.15. Using LTM to solve the following VIE of the second kind

$$\phi(x) = x + \int_{0}^{x} \sin(x - t)\phi(t)dt. \tag{2.121}$$

<span id="page-32-0"></span>Solution From Eq.[\(2.120\)](#page-32-3), we obtain

$$\phi(x) = \mathcal{L}^{-1} \left\{ \frac{\mathcal{L}\{x\}}{1 - \mathcal{L}\{\sin(x)\}} \right\}$$

$$= \mathcal{L} \left\{ \frac{\frac{1}{t^2}}{1 - \frac{1}{t^2 + 1}} \right\}$$

$$= \mathcal{L}^{-1} \left\{ \frac{1}{t^2} + \frac{1}{t^4} \right\}$$

$$= x + \frac{x^3}{6}.$$
(2.122)

# 2.7 Numerical methods

It is worth noting that IEs often do not have analytical solution, and must be solved numerically. So, many researchers have been done to get the Appr. solution of IEs, using different methods [\[26,](#page-44-0) ?, ?, ?]. In the next chapters, we concentrate our interest on illustrating the Appr. solutions.

Numerical analysis is the study of algorithms that use numerical approximation for the problems of mathematical analysis. Numerical analysis naturally finds applications in many fields such as engineering, physical sciences, life sciences, social sciences, medicine, and business. The growth in computing power has revolutionized the use of realistic mathematical models in science and engineering. For example, ordinary differential equations appear in celestial mechanics (predicting the motions of planets, stars, and galaxies); numerical linear algebra is important for data analysis; stochastic differential equations and Markov chains are essential in simulating living cells for medicine and biology. Numerical solution of partial differential equation is almost an important topic in recent years. partial differential equation arise in formulations of problems involving functions of several variables such as the propagation of sound or heat, electrostatics, electrodynamics, fluid flow, and elasticity, etc. Most Mathematical Models which contain differential equations, partial differential equations, integral equations, fractions equations, and mixed equations are solved numerically by different methods as finite difference method, Rang- kota method, variation iteration method, Adomain decomposition method [\[91,](#page-48-1) [17,](#page-43-1) [22,](#page-43-2) [23\]](#page-43-3), Laplace Adomain decomposition method, homotopy analysis method [\[2,](#page-42-3) [15,](#page-43-4) [79,](#page-47-1) [82\]](#page-48-2), homotopy perturbation method [\[25,](#page-44-2) [42,](#page-45-2) [62\]](#page-46-2), Laplace homotopy perturbation method [\[50\]](#page-45-3), and other methods. Therefore, we will review some numerical methods.

# <span id="page-33-0"></span>2.7.1 Quadrature methods for FIE and VIE

<span id="page-33-1"></span>Using quadrature rule, we get

$$\int_{a}^{b} k(x,t)\phi(t)dt = \sum_{j=0}^{n} \omega_{j}k(x,t_{j})\phi(t_{j})$$
(2.123)

where ω<sup>j</sup> are the weight functions.

<span id="page-34-0"></span>Substituting from Eq.[\(2.123\)](#page-33-1) in Eq.(??) yields

$$\mu\phi(x) = f(x) + \lambda \sum_{j=0}^{n} \omega_j k(x, x_j) \phi(x_j). \tag{2.124}$$

The solution for Eq.[\(2.124\)](#page-34-0) may be obtained if we assign x<sup>i</sup> to x which i = 0, 1, 2, ..., n , a ≤ x<sup>i</sup> ≤ b, so Eq.[\(2.124\)](#page-34-0) reduced to a system of equations

$$\mu\phi(x_i) - \lambda \sum_{j=0}^{n} \omega_j k(x_i, x_j) \phi(x_j) = f(x_i).$$
(2.125)

<span id="page-34-1"></span>For any x<sup>i</sup> ∈ [a, b], Eq.[\(2.125\)](#page-34-1) can be represented by

$$(I - \frac{\lambda}{\mu}kD)\tilde{\phi}_i = \frac{1}{\mu}\tilde{f} \tag{2.126}$$

where ϕ˜ <sup>i</sup> = [ϕ(xi)]<sup>T</sup> , ˜f = [f(xi)]<sup>T</sup> , k = [k(x<sup>i</sup> , x<sup>j</sup> )]<sup>T</sup> and D = diag[ω0, ω1, ..., ωn].

### Trapezoidal rule for FIEs and VIEs

The TR is a numerical method used for solving FIE (??) of the second kind. We shall subdivide the interval of integration [a, b] into n equal subintervals of width h<sup>t</sup> where h<sup>t</sup> = b−a n . The general form of TR is

<span id="page-34-2"></span>
$$\int_{a}^{b} k(x,t)\phi(t)dt = \frac{h_{t}}{2} \left[ k(x,t_{0})\phi(t_{0}) + 2\sum_{j=1}^{n-1} k(x,t_{j})\phi(t_{j}) + k(x,t_{n})\phi(t_{n}) \right].$$
(2.127)

At x = x<sup>i</sup> , i = 0, 1, 2, ..., n, so substituting from Eq.[\(2.127\)](#page-34-2) in Eq.(??) yields

<span id="page-34-3"></span>
$$\mu\phi(x_i) = f(x_i) + \frac{\lambda h_t}{2} \left[ k(x_i, t_0)\phi(t_0) + 2\sum_{j=1}^{n-1} k(x_i, t_j)\phi(t_j) + k(x_i, t_n)\phi(t_n) \right]. \tag{2.128}$$

Eq.[\(2.128\)](#page-34-3) can be written in the form

$$\mu\phi_i = f_i + \frac{\lambda h_t}{2} \left[ k_{i,0}\phi_0 + 2\sum_{j=1}^{n-1} k_{i,j}\phi_j + k_{i,n}\phi_n \right]$$
(2.129)

where ϕ<sup>i</sup> = ϕ(xi) , f<sup>i</sup> = f(xi) and ki,n = k(x<sup>i</sup> , xn).

Also, if the same method is used for solving VIE of the second kind, we get

$$\mu\phi_i = f_i + \frac{\lambda h_t}{2} \left[ k_{i,0}\phi_0 + 2\sum_{j=1}^{i-1} k_{i,j}\phi_j + k_{i,i}\phi_i \right]. \tag{2.130}$$

#### Simpson's rule for FIEs and VIEs

The Simpson's 1/3 rule is a numerical method used to solve FIE (??) of the second kind. We shall subdivide the interval of integration [a, b] into positive n equal subintervals of width h<sup>s</sup> where h<sup>s</sup> = b−a <sup>n</sup> where n is even. The general form of Simpson's 1/3 rule is

$$\int_{a}^{b} k(x,t)\phi(t)dt = \frac{h_{s}}{3} [k(x,t_{0})\phi(t_{0}) + 4\sum_{j=1}^{\frac{n}{2}} k(x,t_{2j-1})\phi(t_{2j-1}) + 2\sum_{j=1}^{\frac{n}{2}-1} k(x,t_{2j})\phi(t_{2j}) + k(x,t_{n})\phi(t_{n})].$$
(2.131)

<span id="page-35-1"></span><span id="page-35-0"></span>We shall set t<sup>i</sup> = x<sup>i</sup> , i = 0, 1, 2, ..., n, so Eq.[\(2.131\)](#page-35-0) becomes

$$\int_{a}^{b} k(x,t)\phi(t)dt = \frac{h_{s}}{3} [k(x,x_{0})\phi(x_{0}) + 4\sum_{j=1}^{\frac{n}{2}} k(x,x_{2j-1})\phi(x_{2j-1}) + 2\sum_{j=1}^{\frac{n}{2}-1} k(x,x_{2j})\phi(x_{2j}) + k(x,x_{n})\phi(x_{n})].$$
(2.132)

<span id="page-35-2"></span>Substituting from Eq.[\(2.132\)](#page-35-1) in Eq.(??) yields

$$\mu\phi(x) = f(x) + \frac{\lambda h_s}{3} [k(x, x_0)\phi(x_0) + 4\sum_{j=1}^{\frac{n}{2}} k(x, x_{2j-1})\phi(x_{2j-1}) + 2\sum_{j=1}^{\frac{n}{2}-1} k(x, x_{2j})\phi(x_{2j}) + k(x, x_n)\phi(x_n)].$$
(2.133)

<span id="page-35-3"></span>At x = x<sup>i</sup> , i = 0, 1, 2, ..., n, Eq.[\(2.133\)](#page-35-2) becomes

$$\mu\phi(x_i) = f(x_i) + \frac{\lambda h_s}{3} [k(x_i, x_0)\phi(x_0) + 4\sum_{j=1}^{\frac{n}{2}} k(x_i, x_{2j-1})\phi(x_{2j-1}) + 2\sum_{j=1}^{\frac{n}{2}-1} k(x_i, x_{2j})\phi(x_{2j}) + k(x_i, x_n)\phi(x_n)].$$
(2.134)

Eq.[\(2.134\)](#page-35-3) can be written in the form

$$\mu\phi_i = f_i + \frac{\lambda h_s}{3} \left[ k_{i0}\phi_0 + 4\sum_{j=1}^{\frac{n}{2}} k_{i,2j-1}\phi_{2j-1} + 2\sum_{j=1}^{\frac{n}{2}-1} k_{i,2j}\phi_{2j} + k_{i,n}\phi_n \right]$$
(2.135)

where ϕ<sup>i</sup> = ϕ(xi) , f<sup>i</sup> = f(xi) and ki,n = k(x<sup>i</sup> , xn).

Applying SR for solving VIE of the second kind, we get

$$\mu\phi_i = f_i + \frac{\lambda h_s}{3} \left[ k_{i,0}\phi_0 + 4\sum_{j=1}^{\frac{i}{2}} k_{i,2j-1}\phi_{2j-1} + 2\sum_{j=1}^{\frac{i}{2}-1} k_{i,2j}\phi_{2j} + k_{i,i}\phi_i \right]. \tag{2.136}$$

# <span id="page-36-0"></span>2.7.2 Collocation method for FIEs and VIEs

This method depends on approximating the solution ϕ(x) of the FIE (??) of the second kind as a partial sum of N linearly independent functions ψ1, ψ2, ψ3, ..., ψ<sup>N</sup> on the interval [a, b] s.t.

<span id="page-36-2"></span>
$$S_N(x) = \sum_{i=1}^{N} c_i \psi_i(x)$$
(2.137)

and getting N conditions that give us N equations required for determining the N coefficients (c1, c2, ..., c<sup>N</sup> )of the Appr. solution [\(2.137\)](#page-36-2), so we get this conditions by insisting the error vanishes at N-points x1, x2, ..., x<sup>N</sup> where x<sup>i</sup> = a + ih<sup>c</sup> and h<sup>c</sup> = b−a N . Substituting from Eq.[\(2.137\)](#page-36-2) into Eq.(??) yields an error E(x, c1, c2, ..., c<sup>N</sup> ) s.t.

<span id="page-36-3"></span>
$$\mu S_N(x) = f(x) + \lambda \int_a^b k(x, t) S_N(t) dt + E(x, c_1, c_2, ..., c_N).$$
(2.138)

Insisting the error in Eq.[\(2.138\)](#page-36-3) vanishes at x = x<sup>i</sup> , so Eq.[\(2.138\)](#page-36-3) becomes

$$\mu S_N(x_i) = f(x_i) + \lambda \int_a^b k(x_i, t) S_N(t) dt, \quad 1 \le i \le N.$$
(2.139)

<span id="page-36-1"></span>Also, Using CM for solving VIE of the second kind yields

$$\mu S_N(x_i) = f(x_i) + \lambda \int_0^{x_i} k(x_i, t) S_N(t) dt, \quad 1 \le i \le N.$$
(2.140)

# 2.7.3 Galerkin method for FIEs and VIEs

This method depends on approximating the solution ϕ(x) of the FIE (??) of the second kind as Eq.[\(2.137\)](#page-36-2) and makes the error orthogonal to N linearly independent functions ψ1(x), ψ2(x), ψ3(x), ..., ψ<sup>N</sup> (x) on the interval [a, b].

Substituting from Eq.[\(2.137\)](#page-36-2) into Eq.(??) yields E(x, c1, c2, ..., c<sup>N</sup> ) s.t.

<span id="page-37-1"></span>
$$E(x, c_1, c_2, ..., c_N) = \mu S_N(x) - f(x) - \lambda \int_a^b k(x, t) S_N(t) dt.$$
(2.141)

From GM, the error in Eq.[\(2.141\)](#page-37-1) is orthogonal to N linearly independent functions χ1(x), χ2(x), χ3(x), ..., χ<sup>N</sup> (x) on the interval [a, b], so we have

<span id="page-37-2"></span>
$$\int_{a}^{b} \chi_{j}(y)E(y, c_{1}, c_{2}, ..., c_{N})dy = 0.$$
(2.142)

<span id="page-37-3"></span>Substituting from Eq.[\(2.141\)](#page-37-1) in Eq.[\(2.142\)](#page-37-2) yields

$$\int_{a}^{b} \chi_{j}(y) \left[ \mu S_{N}(y) - f(y) - \int_{a}^{b} k(y, t) S_{N}(t) dt \right] dy = 0, \ 1 \le j \le N.$$
(2.143)

<span id="page-37-4"></span>Eq.[\(2.143\)](#page-37-3) can be written in the form

$$\int_{a}^{b} \chi_{j}(y) \left[ \mu S_{N}(y) - \int_{a}^{b} k(y,t) S_{N}(t) dt \right] dy = \int_{a}^{b} \chi_{j}(y) f(y) dy,$$

$$1 \le j \le N.$$

$$(2.144)$$

Substituting from [\(2.137\)](#page-36-2) in Eq.[\(2.144\)](#page-37-4) yields

$$\int_{a}^{b} \chi_{j}(y) \left[ \mu \sum_{i=1}^{N} c_{i} \psi_{i}(y) - \int_{a}^{b} k(y,t) \sum_{i=1}^{N} c_{i} \psi_{i}(t) dt \right] dy = \int_{a}^{b} \chi_{j}(y) f(y) dy,$$

$$1 \le j \le N.$$
(2.145)

<span id="page-37-0"></span>Applying GM for solving VIE of the second kind yields

$$\int_{a}^{b} \chi_{j}(y) \left[ \mu \sum_{i=1}^{N} c_{i} \psi_{i}(y) - \int_{a}^{x} \left( k(y, t) \sum_{i=1}^{N} c_{i} \psi_{i}(t) \right) dt \right] dy$$

$$= \int_{a}^{b} \chi_{j}(y) f(y) dy, \qquad 1 \leq j \leq N.$$
(2.146)

## 2.7.4 Homotopy Analysis Method

<span id="page-38-0"></span>Consider the following equation

$$\mathcal{N}(\phi(x,t)) = 0, \qquad x \in [a,b], \ t \in [0,T]$$
(2.147)

where  $\mathcal{N}$  denotes the (linear or nonlinear) operator and  $\phi(x,t)$  is an unknown function. Firstly, we describe the homotopy operator  $\mathcal{H}$  as

$$\mathcal{H}(\Phi, p) = (1 - p) \left( \Phi(x, t; p) - \phi_0(x, t) \right) - ph \mathcal{N}(\Phi(x, t; p)), \tag{2.148}$$

where  $p \in [0, 1]$  is the embedding parameter,  $h \neq 0$  describes the convergence control parameter and  $\phi_0(x, t)$  denotes the initial approximate solution of (2.147).

<span id="page-38-3"></span>Suppose that  $\mathcal{H}(\Phi, p) = 0$ , then we obtain the zero order deformation equation

$$(1-p)(\Phi(x,t;p) - \phi_0(x,t)) = ph\mathcal{N}(\Phi(x,t;p)). \tag{2.149}$$

If we put p=0, we get  $\Phi(x,t;0)-\phi_0(x,t)=0$ , which indicates that  $\Phi(x,t;0)=\phi_0(x,t)$ . For p=1, we have  $\mathcal{N}(\Phi(x,t;1))=0$ , which implies that  $\Phi(x,t;1)=\phi(x,t)$ , where  $\phi(x,t)$  is the solution of (2.147). Thus, the variety of parameter  $p:0\to 1$  corresponds with the transformation of problem from the trivial to the original problem (and with the variation of solution from  $\phi_0(x,t)$  to  $\phi(x,t)$ ). If we get the Maclaurin expansion of the function  $\Phi(x,t;p)$  with respect to p, we have

$$\Phi(x,t;p) = \Phi(x,t;0) + \sum_{m=1}^{\infty} \frac{1}{m!} \frac{\partial^m \Phi(x,t;p)}{\partial p^m} \bigg|_{p=0} p^m.$$
(2.150)

<span id="page-38-1"></span>By denoting

$$\psi_m(x,t) = \frac{1}{m!} \frac{\partial^m \Phi(x,t;p)}{\partial p^m} \bigg|_{p=0}, \qquad m = 0, 1, 2, 3, ...,$$
(2.151)

<span id="page-38-2"></span>Eq.(2.150) becomes

$$\Phi(x,t;p) = \psi_0(x,t) + \sum_{m=1}^{\infty} \psi_m(x,t) p^m$$

$$= \sum_{m=0}^{\infty} \psi_m(x,t) p^m.$$
(2.152)

If the series in (2.152) is convergent at p=1, then we obtain

$$\phi(x,t) = \sum_{m=0}^{\infty} \psi_m(x,t).$$
(2.153)

Now, to get the function  $\psi_m(x,t)$ , we differentiate Eq.(2.149) m times with respect to the parameter p, divide the received result by m! and substitute p=0. Thus, we get  $m^{th}$  order deformation equation

$$\psi_m(x,t) - \chi_m \psi_{m-1}(x,t) = hR_m \left( \bar{\psi}_{m-1}, x, t \right), \quad m > 0, \tag{2.154}$$

where  $\bar{\psi}_{m-1} = \{\psi_0(x,t), \psi_1(x,t), \dots, \psi_{m-1}(x,t)\},\$

$$\chi_m = \begin{cases} 0 & m \le 1\\ 1 & m > 1 \end{cases} \tag{2.155}$$

and

$$R_m\left(\bar{\psi}_{m-1}, x, t\right) = \frac{1}{(m-1)!} \left( \frac{\partial^{m-1}}{\partial p^{m-1}} \mathcal{N}\left(\sum_{i=0}^{\infty} \psi_i(x, t) p^i\right) \right) \bigg|_{n=0}.$$
(2.156)

Therefore, the approximate solution is given by

$$\widehat{\phi}_M(x,t,h) = \sum_{m=0}^{M} \psi_m(x,t), \quad M = 1, 2, \dots$$
(2.157)

## <span id="page-39-0"></span>2.7.5 Homotopy Perturbation Method

We describe the homotopy perturbation method as [25, 42, 62] for a general type of the nonlinear differential equation with boundary conditions

<span id="page-39-1"></span>
$$A(u) - f(r) = 0, \ r \in \Omega,$$
(2.158)

$$B\left(u, \frac{\partial u}{\partial n}\right) = 0, \quad r \in \Gamma, \tag{2.159}$$

where A is a general differential operator, B is a boundary operator, f(r) is an known analytical function and  $\Gamma$  is the boundary of the domain. The operator A can be divided into two parts L and N where L is a linear operator and N is a nonlinear operator. Therefore, equation (2.158) can be rewritten as

$$L(u) + N(u) - f(r) = 0. (2.160)$$

By the homotopy technique, we define a homotopy function  $H(r,p): \Omega \times [0,1] \to R$  as

<span id="page-39-2"></span>
$$H(u, p) = (1 - p)[L(u) - L(u_0)] + p[A(u) - f(r)] = 0, \quad p \in [0, 1], r \in \Omega$$
(2.161)

where p ∈ [0, 1] and u<sup>0</sup> is an initial approximation for [\(2.158\)](#page-39-1) with

$$H(u,0) = L(u) - L(u_0) = 0, \quad H(u,1) = A(u) - f(r) = 0.$$
(2.162)

We assume that the solution of [\(2.158\)](#page-39-1) can be written as a power series in p

<span id="page-40-1"></span>
$$v = \sum_{k=0}^{\infty} p^k u_k \tag{2.163}$$

Substituting from [\(2.163\)](#page-40-1) in [\(2.161\)](#page-39-2) and comparing the coefficients of powers of p yields a successive procedure to determine uk. Finally, by setting p = 1, we obtain the solution of [\(2.158\)](#page-39-1). For applying Laplace homotopy perturbation method we have steps the first we applied Laplace transform on equation and then applied Laplace homotopy perturbation method. Finally, we applied Laplace inverse to get the solution numerically.

# Comparison between the homotopy analysis method and homotopy perturbation method [\[81\]](#page-48-3)

Both methods "Homotopy Perturbation Method and Homotopy Analysis Method" are in principle based on Taylor series with respect to an embedding parameter. Besides, both can give very good approximations by means of a few terms, if initial guess and auxiliary linear operator are good enough. The difference is that, "the homotopy perturbation method" had to use a good enough initial guess, but this is not absolutely necessary for the homotopy analysis method. This is mainly because the homotopy analysis method contains the auxiliary parameter(h), which provides us with a simple way to adjust and control the convergence region and rate of solution series. So, the homotopy analysis method is more general.

# <span id="page-40-0"></span>2.7.6 Adomian Decomposition Method

In this section, we illustrate the idea of Adomian decomposition method as [\[91,](#page-48-1) [17\]](#page-43-1). Let us consider the nonlinear differential equation is

<span id="page-40-2"></span>
$$L(u) + R(u) + N(u) - g(r) = 0, (2.164)$$

where L is the highest derivative order in time which have inverse operator L −1 , R is a linear differentiable operator and N is a nonlinear differentiable operator. Applying the inverse operator L −1 to both sides of [\(2.164\)](#page-40-2) and using the given condition

$$u = f - L^{-1}[R(u) + N(u)], (2.165)$$

where the function f(x) represents the terms arising from integration the source term g(x). According to Adomian decomposition method the approximate solution u(x) is defined by the series:

$$u(x) = \sum_{n=0}^{N} u_i(x), \quad N \in \mathcal{N},$$
(2.166)

where the components un(x) are determined from the following relations

$$u_0(x) = f(x). (2.167)$$

$$u_{k+1}(x) = -L^{-1} \left[ R\left( u_k(x) \right) + N\left( u_k(x) \right) \right], \quad k \ge 0.$$
(2.168)

The nonlinear operator N(u) can be decomposed into an infinite series of a polynomials as

$$N(u) = \sum_{k=0}^{\infty} A_k.$$
(2.169)

Where A<sup>k</sup> are so called the Adomian polynomials which given by

$$A_k = \frac{1}{k!} \left[ \frac{d^k}{d\lambda^k} \left\{ N\left(\sum_{k=0}^{\infty} \lambda^i u_i(x)\right) \right\} \right]_{\lambda=0}.$$
(2.170)

- <span id="page-42-0"></span>[1] A. Okubo, (1980), Diffusion and Ecological Problems; Mathematical Models.: Springer-Verlag.
- <span id="page-42-3"></span>[2] A. S. Rahby, M. A. Abdou and G. A. Mosa, On The Solutions of the Second Kind Nonlinear Volterra-Fredholm Integral Equations via Homotopy Analysis Method, International Journal of Analysis and Applications, 20 (35) (2022).
- [3] A. A. Badr. Block-by-block method for solving nonlinear Volterra-Fredholm integral equation. *Mathematical Problems in Engineering*, Artical ID 537909, doi:10.1155/2010/537909, (2010) 8 pages.
- [4] A. A. Hemeda. A friendly iterative technique for solving nonlinear integro-differential and systems of nonlinear integro-differential equations. *International Journal of Computational Methods*, 15(03):1850016, 2018.
- [5] A. A. Khajehnasiri. Numerical solution of nonlinear 2D Volterra–Fredholm integrodifferential equations by two-dimensional triangular function.*International Journal of Applied and Computational Mathematics*, 2(4):575–591, 2016.
- [6] A. Khajehnasiri, M. Safavi, and J. Banar. Application of Legendre operational matrix to solution of two dimensional nonlinear Volterra integro-differential equation. *Caspian Journal of Mathematical Sciences (CJMS)*, 9(2):321–339, 2020.
- [7] A. M. Al-Bugami and J. G. Al-Juaid. Runge-Kutta method and bolck by block method to solve nonlinear Fredholm-Volterra integral equation with continuous kernel. *Journal of Applied Mathematics and Physics*, 8(09):2043, 2020.
- <span id="page-42-2"></span>[8] A. Wazwaz. *Linear and Nonlinear Integral Equations*, volume 639. Springer, 2011.
- [9] C. Brezinski and M. Redivo-Zaglia. Extrapolation methods for the numerical solution of nonlinear Fredholm integral equations. *Journal of Integral Equations and Applications*, 31(1):29– 57, 2019.
- <span id="page-42-1"></span>[10] C. Constanda and M. E. Perez. ´ *Integral Methods in Science and Engineering*. Springer, 2010.

[11] C. N. Angstmann, I. C. Donnelly, B. I. Henry, B. A. Jacobs, T. A. M. Langlands, and J. A. Nichols. From stochastic processes to numerical methods: A new scheme for solving reaction subdiffusion fractional partial differential equations. *Journal of Computational Physics*, 307:508–534, 2016.

- [12] D. Edward, and Hamson, M. J., (1989), Guide to Mathematical Modelling.:Macmilan, London
- [13] D. N. P. Murthy, Page, N. W. and Rodin, E. Y. , (1990), Mathematical Modelling; A Tool for Problem Solving in Engineering, Physical, Biological and Social Sciences.: Pergamon Press, Oxford.
- [14] E. C. Pielou, (1969), An introduction to Mathematical Ecology.: Wiley, New York.
- <span id="page-43-4"></span>[15] E. Hetmaniok, D. Słota, T. Trawinski, and R. Wituła. Usage of the homotopy analysis method ´ for solving the nonlinear and linear integral equations of the second kind. *Numerical Algorithms*, 67(1):163–185, 2014.
- <span id="page-43-0"></span>[16] E. Kreyszig. *Introductory functional analysis with applications*, volume 1. wiley New York, 1978.
- <span id="page-43-1"></span>[17] E. M. E. Zayed, T. A. Nofal, and K. A. Gepreel. Homotopy perturbation and adomain decomposition methods for solving nonlinear boussinesq equations. *Communications on Applied Nonlinear Analysis*, 15(3):57, 2008.
- [18] F. Ghoreishi and M. Hadizadeh. Numerical computation of the Tau approximation for the Volterra-Hammerstein integral equations. *Numerical Algorithms*, 52(4):541–559, 2009.
- [19] F. M Al-Saar and K. P. Ghadle. Solving nonlinear Fredholm integro-differential equations via modifications of some numerical methods. *Advances in the Theory of Nonlinear Analysis and its Application*, 5(2):260–276, 2021.
- [20] F. Mirzaee and E. Hadadiyan. Applying the modified block-pulse functions to solve the threedimensional Volterra–Fredholm integral equations. *Applied Mathematics and Computation*, 265:759–767, 2015.
- [21] F. Mirzaee, E. Hadadiyan, and S. Bimesl. Numerical solution for three-dimensional nonlinear mixed Volterra–Fredholm integral equations via three-dimensional block-pulse functions. *Applied Mathematics and Computation*, 237:168–175, 2014.
- <span id="page-43-2"></span>[22] G. A. Mosa, M. A. Abdou, F. A. Gawish, and M. H. Abdalla, On the behaviour solutions of fractional and partial integro differential heat equations and its numerical solutions. Math. Slovaca, 72, (2022).
- <span id="page-43-3"></span>[23] G. A. Mosa, M. A. Abdou, and A. S. Rahby. Numerical solutions for nonlinear Volterra-Fredholm integral equations of the second kind with a phase lag. *AIMS Mathematics*, 6(8):8525–8543, 2021.

[24] H. Almasieh and J. N. Meleh. Numerical solution of a class of mixed two-dimensional nonlinear Volterra–Fredholm integral equations using multiquadric radial basis functions. *Journal of Computational and Applied Mathematics*, 260:173–179, 2014.

- <span id="page-44-2"></span>[25] H. Aminikhah. An analytical approximation to the solution of chemical kinetics system. *Journal of King Saud University-Science*, 23(2):167–170, 2011.
- <span id="page-44-0"></span>[26] H. Brunner. On the numerical solution of nonlinear Volterra–Fredholm integral equations by collocation methods. *SIAM Journal on Numerical Analysis*, 27(4):987–1000, 1990.
- <span id="page-44-1"></span>[27] H. Hochstadt. *Integral equations*. John Wiley & Sons, 1989.
- [28] H. Jafari, M. Nazari, D. Baleanu, and C. M. Khalique. A new approach for solving a system of fractional partial differential equations. *Computers & Mathematics with Applications*, 66(5):838–843, 2013.
- [29] H. Richard. *Fractional Calculus: An Introduction for Physicists*. World Scientific, 2014.
- [30] H. Thieme. A model for the spatial spread of an epidemic. *Journal of Mathematical Biology*, 4(4):337–351, 1977.
- [31] H. Vosughi, E. Shivanian, and S. Abbasbandy. A new analytical technique to solve Volterra's integral equations. *Mathematical methods in the applied sciences*, 34(10):1243–1253, 2011.
- [32] I. A. Moneim and G. A. Mosa, A realistic model for the periodic dynamics of the hand-footand-mouth disease, AIMS Mathematics, 7 (2), (2021).
- [33] I. A. Moneim and G. Mosa, Modelling Childhood Infectious Diseases with Infectious Latent and Loss of Immunity. Global Journal of Pure and Applied Mathematics 16 (3), (2020).
- [34] I. A. Moneim, (1994), Mathematical Modelling in Public Health with Special Emphasis on Infectious Hepatitis (and ' or) Schistosomiasis in Egypt.: MSc., Benha, Egypt.
- [35] I. Aziz and Siraj ul Islam. New algorithms for the numerical solution of nonlinear Fredholm and Volterra integral equations using Haar wavelets. *Journal of Computational and Applied Mathematics*, 239:333–345, 2013.
- [36] I. Khan, M. Asif, R. Amin, Q. Al-Mdallal, and F. Jarad. On a new method for finding numerical solutions to integro-differential equations based on Legendre multi-wavelets collocation. *Alexandria Engineering Journal*, 61(4):3037–3049, 2022.
- [37] I. L. El-Kalla. Convergence of the Adomian method applied to a class of nonlinear integral equations. *Applied mathematics letters*, 21(4):372–376, 2008.
- [38] I. L. El-Kalla. Error estimates for series solutions to a class of nonlinear integral equations of mixed type. *Journal of Applied Mathematics and Computing*, 38(1-2):341–351, 2012.

[39] J. N. Kapur, (1992), Mathematical Models in Biology and Medicine.: Affiliated East-Weast Press, New Delhi.

- [40] J. N. Kapur, (1988), Mathematical Modelling.: Wiley Eastern Limited, New Delhi.
- [41] J. A. Metz and O. Diekmann. *The Dynamics of Physiologically Structured Populations*, volume 68. Springer, 2014.
- <span id="page-45-2"></span>[42] J. He. Homotopy perturbation method for solving boundary value problems. *Physics letters A*, 350(1-2):87–88, 2006.
- [43] J. S. Ardabili and Y. Talaei. Chelyshkov collocation method for solving the two-dimensional Fredholm–Volterra integral equations. *International Journal of Applied and Computational Mathematics*, 4(1):1–13, 2018.
- [44] K. R. Nagle, and Saff, E. B., (1989), Fundamentals of Differential Equations.:Banjamin Cummings, California.
- <span id="page-45-0"></span>[45] K. E. Atkinson. *The Numerical Solution of Integral Equations of the Second Kind*. Cambridge University Press, Cambridge, 1997.
- <span id="page-45-1"></span>[46] K. Maleknejad and M. Hadizadeh. A new computational method for Volterra-Fredholm integral equations. *Computers & Mathematics with Applications*, 37(9):1–8, 1999.
- [47] K. Maleknejad and M. S. Dehkordi. Numerical solutions of two-dimensional nonlinear integral equations via Laguerre Wavelet method with convergence analysis. *Applied Mathematics-A Journal of Chinese Universities*, 36(1):83–98, 2021.
- [48] K. Maleknejad, J. Rashidinia, and T. Eftekhari. Numerical solution of three-dimensional Volterra–Fredholm integral equations of the first and second kinds based on Bernstein's approximation. *Applied Mathematics and Computation*, 339:272–285, 2018.
- [49] L. S. Jacoby, and Skowalik J., (1981), Mathematical Modelling with Computers.: Prentice Hall, New Jersey.
- <span id="page-45-3"></span>[50] M. A. Abdou, A. A. Soliman, M. H. Abdalla, F. A. Gawish, and G. A. Mosa, On Existence and Uniqueness of Fractional Linear Integro Partial Differential Equation with Evolution Kernel Using Modified Bielecki Method and its Numerical Solution. Benha Journal of Applied Sciences (BJAS), Vol. (5) Issue (7) Part (2), (2020).
- [51] M. A. Abdou and M. Basseem. Numerical treatments for solving nonlinear mixed integral equation. *Alexandria Engineering Journal*, 55(4):3247–3251, 2016.
- [52] M. A. Abdou and M. I. Youssef. On a method for solving nonlinear integro differential equation of order n. *Journal of Mathematics and Computer Science*, 25:322–340, 2022.

[53] M. A. Abdou, A. A. Badr, and M. B. Soliman. On a method for solving a two-dimensional nonlinear integral equation of the second kind. *Journal of computational and applied mathematics*, 235(12):3589–3598, 2011.

- [54] M. A. Abdou, A. A. Soliman, and M. A. Abdel-Aty. Analytical results for quadratic integral equations with phase-lag term. *Journal of Applied Analysis & Computation*, 10(4):1588–1598, 2020.
- [55] M. A. Abdou, I. L. El-Kalla, and A. M. Al-Bugami. Numerical solution for Volterra-Ferdholm integral equation with a generalized singular kernel. *Journal of Modern Methods in Numerical Mathematics*, 2(1-2):1–17, 2011.
- [56] M. A. Abdou, M. N. Elhamaky, A. A. Soliman, and G. A. Mosa. The behaviour of the maximum and minimum error for Fredholm-Volterra integral equations in two-dimensional space. *Journal of Interdisciplinary Mathematics*, pages 1–22, 2021.
- [57] M. A. Abdou, W. G. El-Sayed, and E. I. Deebs. A solution of a nonlinear integral equation. *Applied mathematics and computation*, 160(1):1–14, 2005.
- <span id="page-46-1"></span>[58] M. A. Goldberg. *Solution Methods for Integral Equations: Theory and Applications*, volume 18. Springer Science & Business Media, 2013.
- [59] M. Dehghan and A. Saadatmandi. Chebyshev finite difference method for Fredholm integrodifferential equation. *International Journal of Computer Mathematics*, 85(1):123–130, 2008.
- [60] M. I. Berenguer and D. Gamez. Numerical solving of several types of two-dimensional inte- ´ gral equations and estimation of error bound. *Mathematical Methods in the Applied Sciences*, 41(17):7351–7366, 2018.
- [61] M. I. Berenguer, D. Gamez, and A. J. L ´ opez-Linares. Fixed point techniques and Schauder ´ bases to approximate the solution of the first order nonlinear mixed Fredholm–Volterra integro-differential equation. *Journal of Computational and Applied Mathematics*, 252:52– 61, 2013.
- <span id="page-46-2"></span>[62] M. Javidi and B. Ahmad. Numerical solution of fractional partial differential equations by numerical laplace inversion technique. *Advances in Difference Equations*, 1(2013):1–18, 2013.
- [63] M. Kazemi. Approximating the solution of three-dimensional nonlinear Fredholm integral equations. *Journal of Computational and Applied Mathematics*, 395:113590, 2021.
- [64] M. Kazemi. Triangular functions for numerical solution of the nonlinear Volterra integral equations. *Journal of Applied Mathematics and Computing*, pages 1–24, 2021.
- <span id="page-46-0"></span>[65] M. M. El-Borai, M. A. Abdou, and M. M. El-Kojok. On a discussion of nonlinear integral equation of type Volterra-Fredholm. *Journal of the Korean Society for Industrial and Applied Mathematics*, 10(2):59–83, 2006.

[66] M. Mohammadi, A. Zakeri, and M. Karami. An approximate solution of bivariate nonlinear Fredholm integral equations using hybrid block-pulse functions with Chebyshev polynomials. *Mathematical Sciences*, 15(1):1–9, 2021.

- [67] M. R. M. Rao and P. Srinivas. Asymptotic behavior of solutions of Volterra integrodifferential equations. *Proceedings of the American Mathematical Society*, pages 55–60, 1985.
- <span id="page-47-0"></span>[68] M. Rahman. *Integral Equations and Their Applications*.WIT press, 2007.
- [69] N. T. J. Bailey, (1975), The Mathematical Theory of Infectious Diseases and Its Applications.: Griffin, London.
- [70] N. Karamollahi, M. Heydari, and G. B. Loghmani. Approximate solution of nonlinear Fredholm integral equations of the second kind using a class of Hermite interpolation polynomials. *Mathematics and Computers in Simulation*, 187:414–432, 2021.
- [71] N. Rohaninasab, K. Maleknejad, and R. Ezzati. Numerical solution of high-order Volterra– Fredholm integro-differential equations by using Legendre collocation method. *Applied Mathematics and Computation*, 328:171–188, 2018.
- [72] O. Diekmann. Thresholds and travelling waves for the geographical spread of infection. *Journal of mathematical biology*, 6(2):109–130, 1978.
- [73] P. Assari and M. Dehghan. A meshless local discrete Galerkin (MLDG) scheme for numerically solving two-dimensional nonlinear Volterra integral equations. *Applied Mathematics and Computation*, 350:249–265, 2019.
- [74] R. Amin, I. Mahariq, K. Shah, M. Awais, and F. Elsayed. Numerical solution of the second order linear and nonlinear integro-differential equations using Haar wavelet method. *Arab Journal of Basic and Applied Sciences*, 28(1):12–20, 2021.
- [75] R. Hilfer et al. *Applications of Fractional Calculus in Physics*, volume 35. World Scientific Singapore, 2000.
- [76] R. Katani. Numerical solution of the Fredholm integral equations with a quadrature method. *SeMA Journal*, 76(2):271–276, 2019.
- [77] S. Abbasbandy and E. Shivanian. A new analytical technique to solve Fredholm's integral equations. *Numerical algorithms*, 56(1):27–43, 2011.
- [78] S. H. Behiry, R. A. Abd-Elmonem, and A. M. Gomaa. Discrete Adomian decomposition solution of nonlinear Fredholm integral equation. *Ain Shams Engineering Journal*, 1(1):97– 101, 2010.
- <span id="page-47-1"></span>[79] S. Kumar, J. Singh, D. Kumar, and S. Kapoor. New homotopy analysis transform algorithm to solve Volterra integral equation. *Ain Shams Engineering Journal*, 5(1):243–246, 2014.

[80] S. Kumbinarasaiah and R. A. Mundewadi. The new operational matrix of integration for the numerical solution of integro-differential equations via Hermite wavelet. *SeMA Journal*, 78(3):367–384, 2021.

- <span id="page-48-3"></span>[81] S. Liao Comparison between the homotopy analysis method and homotopy perturbation method. *Appl. Math. Comput.*, 169: 1186–1194, 2005.
- <span id="page-48-2"></span>[82] S. Liao. Homotopy analysis method: a new analytic method for nonlinear problems. *Applied Mathematics and Mechanics*, 19(10):957–962, 1998.
- <span id="page-48-0"></span>[83] S. M. Zemyan. *The Classical Theory of Integral Equations: A Concise Treatment*. Springer Science & Business Media, 2012.
- [84] S. Micula. Numerical solution of two-dimensional Fredholm–Volterra integral equations of the second kind. *Symmetry*, 13(8):1326, 2021.
- [85] S. Momani, Z. Odibat, and V. S. Erturk. Generalized differential transform method for solving a space-and time-fractional diffusion-wave equation. *Physics Letters A*, 370(5-6):379–387, 2007.
- [86] S. Saha Ray and S. Behera. Comparison of two wavelet methods for accurate solution of twodimensional nonlinear Volterra integral equation. *Iranian Journal of Science and Technology, Transactions A: Science*, 45(6):2091–2108, 2021.
- [87] T. M. Atanackovic, S. Pilipovi ´ c, B. Stankovi ´ c, and D. Zorica. ´ *Fractional Calculus with Applications in Mechanics*. Wiley Online Library, 2014.
- [88] V. Capasso, (1993), Lecture Notes in Biomathematics; Mathematical Structures of Epidemic Systems.: Springer, Berlin.
- [89] V. Daftardar-Gejji and S. Bhalekar. Solving fractional boundary value problems with dirichlet boundary conditions using a new iterative method. *Computers & Mathematics with Applications*, 59(5):1801–1809, 2010.
- [90] V. Volterra. *Theory of Functionals and of Integral and Integro-Differential Equations*. Dover, 1995.
- <span id="page-48-1"></span>[91] X. Su and S. Zhang. Solutions to boundary-value problems for nonlinear differential equations of fractional order. *Electronic Journal of Differential Equations (EJDE)[electronic only]*, 2009(26):1–15, 2009.
- [92] Y. Goltser and E. Litsyn. Volterra integro-differential equations and infinite systems of ordinary differential equations. *Mathematical and computer Modelling*, 42(1-2):221–233, 2005.
- [93] Z. M. Odibat. Differential transform method for solving Volterra integral equation with separable kernels. *Mathematical and Computer Modelling*, 48(7-8):1144–1149, 2008.