function varargout = estbat(varargin)
% ESTBAT Batch Estimator.
%
%   [T,X,P] = ESTBAT(DYNFUN,DATFUN,TSPAN,X0,P0) updates x0 with the
%   measurement sequence generated by y = h(t,x) + v over TSPAN using a
%   weighted least-squares batch solution with a priori information given
%   by inv(P0).  It then integrates the system of differential equations
%   x' = f(t,x) from T0 to TFINAL with an updated initial condition, and
%   returns the state and covariance over TSPAN. The time span can be
%   specified as TSPAN = [T0 T1 T2 ... TFINAL] or TSPAN = [T0 TFINAL].  For
%   the latter, TSPAN is replaced by the time vector determined by the
%   integrator specified by the ODESOLVER option whose default is ODE113.
%
%      Function DYNFUN(T,X) must return a column vector corresponding to
%   f(t,x).  If DYNFUN is "vectorized," then f(t,x) must be a 2-D array
%   with each column corresponding to f(t(i),x(t(i)).  Function DYNFUN(T,X)
%   must return an additional output if called with two output arguments,
%   which may either be a matrix corresponding to A(t), or else an empty
%   matrix, in which case ESTINT will numerically compute A(t) using
%   NUMJAC. If A(t) is supplied, it must be a 3-D array for the vectorized
%   case, with each "slice" corresponding to A(t(i)).
%      Function DATFUN must return a column vector corresponding to h(t,x),
%   and two additional outputs corresponding to the measurement partials,
%   H(t) = dh(t,x)/dx, and the measurement noise covariance, R = E[vv'],
%   where y = h(t,x) + v.  As an alternate to supplying H(t), DATFUN may
%   return an empty matrix as its second output, in which case OMINUSC will
%   numerically compute H(t) using NUMJAC.  If DATFUN is "vectorized," then
%   h(t,x) must return as its first output a 2-D array with each column
%   corresponding to h(t(i),x(t(i)); its next two outputs must be 3-D
%   arrays with each "slice" corresponding to H(t(i)) and R(t(i)),
%   respectively.
%      The rows in the solution array X correspond to times returned in the
%   column vector T.  The rows in the solution covariance array P
%   correspond to the unique lower triangular elements of P at the times T,
%   appended by row from column 1 to the main diagonal.  The Ith row may be
%   reformed into a matrix using UNSCRUNCH(P(I,:)).
%
%   [T,X,P] = ESTBAT(DYNFUN,DATFUN,TSPAN,X0,P0,OPTIONS) performs as above
%   with default properties replaced by values in OPTIONS, an argument
%   created with the SETODTBXOPTIONS or ODTBXOPTIONS functions.  See the
%   ODTBXOPTIONS function for details.
%      If multiple monte-carlo cases are specified using SETODTBXOPTIONS, 
%   then the output data will stored in cell arrays, with each cell array 
%   element corresponding to an entire time series for each monte carlo 
%   case.
%   Note that as of ODTBX R2013a, OPTIONS can be either a standard
%   ODTBXOPTIONS structure, or a struct of two ODTBXOPTIONS structures that
%   are used separately for truth and estimated computations. The latter
%   method is achieved by settings OPTIONS as a struct:
%      >> options.tru = setOdtbxOptions(...);
%      >> options.est = setOdtbxOptions(...);
%      >> [...] = estseq(..., options, ...);
%   Using this method, all options common to truth and estimated
%   computations are taken from the options.est structure.
%
%   [T,X,P] = ESTBAT(DYNFUN,DATFUN,TSPAN,X0,P0,OPTIONS,DYNARG,DATARG)
%   passes DYNARG to DYNFUN and DATARG to DATFUN as DYNFUN(T,X,DYNARG) and
%   DATFUN(T,X,DATARG), respectively.  Use OPTIONS = [] as a place holder
%   if no options are set.
%
%   [T,X,P] = ESTBAT(DYNFUN,DATFUN,TSPAN,X0,P0,OPTIONS,DYNARG,DATARG,S,C)
%   passes in solve-for and consider mapping matrices, S and C,
%   respectively.  These matrices partition the state into a solve-for
%   partition, S*x, and a consider partition, C*x.  Only parameters in the
%   former partition will be updated from the meaurements.  To handle the
%   different dimensions of the full state vs. the solve-for and consider
%   partitions, the user can either design DYNFUN and DATFUN to check for
%   this, or specify DYNFUN and/or DATFUN as structures, whose fields are
%   *.tru and *.est. The function specified in *.tru will be used to
%   evaluate the full state, and the one in *.est will be used for the
%   solve-for partition.  Similar conventions may be used for X0, P0,
%   DYNARG, and DATARG, i.e. X0.Xo and X0.Xbaro, P0.Po and P0.Pbaro,
%   DYNARG.tru and DYNARG.est, DATARG.tru and DATARG.est. Use [] as a place
%   holder for OPTIONS, DYNARG, and/or DATARG as necessary if these inputs
%   are not required.
%
%   [T,X,P,E,DY] = ESTBAT(DYNFUN,DATFUN,TSPAN,X0,P0,...) will also return
%   the estimation errors E and the measurement residuals DY.
%
%   [T,X,P,E,DY,PA,PV,PW,PHATA,PHATV,PHATW] = ESTBAT(...) returns several
%   addditional covariance matrices: PA, PV, and PW are the true
%   covariances that arise only from the true  _a priori_ covariance, the
%   true measurement noise covariance, and the true process noise
%   covariance, respectively;  PHATA, PHATV , and PHATW are the estimator's
%   covariances that arise only from the design values of the  _a priori_
%   covariance and the measurement noise covariance. Since the batch 
%   estimator does not model process noise, PHATW is identically zero.
%
%   [T,X,P,E,DY,PA,PV,PW,PHATA,PHATV,PHATW,SIGSA,PDY,PDYT] = ESTBAT(...) 
%   als returns SIGSA, the matrix of linear sensitivity of the solution at 
%   the anchor time to mismodeling of the distributions of the _a priori_
%   parameters (both solve-fors and considers); PDY, the formal residual 
%   error covariance corresponding to DY; and PDYT the true measurement 
%   error covariance.
%
%   Note that P0 = [] or P0 = Inf will generate a least-squares correction
%   without a priori information. In simulating truth data, no initial
%   condition error is applied.  In such cases, the system must be fully
%   observable from the data, or an error will result.
%
%   If multiple monte-carlo cases are specified using SETODTBXOPTIONS, 
%   this is capable of running the monte-carlo cases in parallel.  Simply
%   open a pool of parallel workers using 'matlabpool' and estbat will
%   utilize them.  The only contraints placed on the caller when running
%   monte-carlo cases in parallel are:
%    1. the dynfun and datafun functions must not retain state that later 
%       monte-carlo runs will rely on
%    2. any Java classes used must be serializable
%    3. any variables that are used in the dynfun or datafun functions but
%       are setup before the call to estbat must appear somehwhere in the 
%       setup code (e.g. setting up a variable by loading it from a file 
%       will assign it a value without the variable name ever appearing in 
%       the code - this will cause an error in parallel execution)
%
%   Examples
%      Given xdot = pr2bp(t,x,mu), [y,H,R] = range2d(t,x,sig):
%         estbat(@pr2bp,@range2d,tspan,x0,P0,[],mu,sig)
%         [t,x,P] = estbat(@pr2bp,@range2d,tspan,x0,P0,[],mu,sig)
%         estsol = estbat(@pr2bp,@range2d,tspan,x0,P0,[],mu,sig)
%      With opts = setOdtbxOptions('OdeSolver',@ode45,...):
%         estbat(@pr2bp,@range2d,tspan,x0,P0,opts,mu,sig)
%
%   Seach Categories (keywords): Estimation
%
%   See also
%      options handling:      ODTBXOPTIONS, SETODTBXOPTIONS,
%                             GETODTBXOPTIONS
%      evaluating solutions:  ESTVAL
%      other ODTBX filters:   ESTSEQ
%      other ODTBX utilties:  INTEG, OBSERV
%      ODE solvers:           ODE113, ODE23, ODE45
%      covariance storage:    SCRUNCH, UNSCRUNCH
%
% (This file is part of ODTBX, The Orbit Determination Toolbox, and is
%  distributed under the NASA Open Source Agreement.  See file source for
%  more details.)

% ODTBX: Orbit Determination Toolbox
% 
% Copyright (c) 2003-2011 United States Government as represented by the
% administrator of the National Aeronautics and Space Administration. All
% Other Rights Reserved.
% 
% This file is distributed "as is", without any warranty, as part of the
% ODTBX. ODTBX is free software; you can redistribute it and/or modify it
% under the terms of the NASA Open Source Agreement, version 1.3 or later.
% 
% You should have received a copy of the NASA Open Source Agreement along
% with this program (in a file named License.txt); if not, write to the 
% NASA Goddard Space Flight Center at opensource@gsfc.nasa.gov.

% Russell Carpenter
% NASA Goddard Space Flight Center

% NOTE: The interface design of this function is based on ODE45.M, which
% is copyrighted by The MathWorks, Inc.

% Modification History
% ---------------------
% 2009-09-14 S. Hur-Diaz     Corrected the initialization of the estimator
%                            states in the Monte Carlo simulation
%
% 2009-09-18 S. Hur-Diaz     Include Pdy and Pdyt measurement error 
%                            calculations and output
%
% 2009-10-27 S. Hur-Diaz     Added a check for NaN measurements in the 
%                            covariance analysis section of the code and
%                            modified the accumulation of the information
%                            matrix J accordingly as well as zeroing out
%                            corresponding elements of the gain matrix.
%
% 2010-07-06 K. Getzandanner Corrected the calculation of the gain matrix 
%                            for NaN measurements
% 2010-12-19 J. Gaebler      Corrected sensitivity calculation for
%                            "dynamic" consider parameters
% 2011-02-07 R. Carpenter    Added test case 3 that will stimulate
%                            "dynamic" consider parameters
% 2012-08-06 R. Carpenter    Changed monte carlo solution method so that it
%                            uses the same algorith as the linear
%                            covariance analysis method.  For long-arc
%                            solutions with weak observability, the method
%                            used in lincov was found to be much more
%                            stable, as it avoids the need to invert an
%                            ill-conditioned normal matrix.  To solve for
%                            the batch gain matrix, a more stable solution
%                            based on the QR decomposition was used.
%                            Finally, the use of the option
%                            UpdateIterations was changed so that it is now
%                            an upper limit on iterations, rather than a
%                            fixed limit.  The solver will now iterate as
%                            many times as necessary in order to reduce the
%                            change in the solution from one iteration to
%                            the next, until the norm of the change is less
%                            than 0.1*det(Pao+Pvo+Pwo)^(1/2/n), ie it is
%                            less than 1/10th of the mean standard
%                            deviation of the truth covariance computed by
%                            the lincov, up to a maximum set by
%                            UpdateIterations, which defaults to 10.
% 2012-08-28 R. Mathur       Extracted regression test
% 2013-05-01 R. Mathur       Fully extracted regression test to estbat_test
%                            Added ability to specify separate truth & estimated
%                            options structures for the options input.

%% ESTBAT: Batch Estimator
%
% ESTBAT is the primary batch estimator for OD Toolbox.  The original
% version was a fairly simple batch estimator of the sort described Tapley,
% Schutz, and Born, and other standard textbooks.  The current version is a
% fairly significant generalization, based primarily on the work of
% Markley, et al. (F. L. Markley, E. Seidewitz, and M. Nicholson, "A
% General Model for Attitude Determination Error Analysis,"  _NASA
% Conference Publication 3011: Flight Mechanics/Estimation Theory
% Symposium_, May 1988, pp. 3-25, and F. L. Markley, E. Seidewitz, and J.
% Deutschmann, "Attitude Determination Error Analysis: General Model and
% Specific Application,"  _Proceedings of the CNES Space Dynamics
% Conference_, Toulouse, France, November 1989, pp. 251-266).
%
% The following mathematical specifications were published from comments
% embedded within the m-file.

%% Input Parsing and Setup
% Parse the input list and options structure.  Pre-allocate arrays, using a
% cell index for the monte carlo cases, which will avoid the need for each
% case to have time series at common sample times.  Use an extra dimension
% "on the right" within each monte carlo case to accomodate the time
% series, which will avoid the need for conversions from cell to double for
% plotting.  Where it makes sense, use cell indices to partition
% large matrices into submatrices, to avoid the need for opaque indexing
% computations.
%
% This should be a subfunction, or if there is a lot of commonality with
% estseq's version, a private function.
%
% The full self-test has been extracted to estbat_test.m to conform to
% the new regression testing framework.
%
% If there are no output arguments, then plot the results of a particular
% input self-test as a demo.

if(nargin < 4)
    error('estbat no longer supports direct regression testing. Please use estbat_test.');
end

if nargin >= 4,
    if all(isfield(varargin{1}, {'tru','est'})),
        dynfun = varargin{1};
    else
        dynfun.tru = varargin{1};
        dynfun.est = varargin{1};
    end
    if all(isfield(varargin{2}, {'tru','est'})),
        datfun = varargin{2};
    else
        datfun.tru = varargin{2};
        datfun.est = varargin{2};
    end
    tspan = varargin{3};
    if isstruct(varargin{4}),
        Xo = varargin{4}.Xo;
        Xbaro = varargin{4}.Xbaro;
    else
        Xo = varargin{4};
        Xbaro = varargin{4};
    end
end
if nargin >= 5,
    if isstruct(varargin{5}),
        Po = varargin{5}.Po;
        Pbaro = varargin{5}.Pbaro;
    else
        Po = varargin{5};
        Pbaro = varargin{5};
    end
    if isempty(Po) || all(all(isinf(Po)))
        Po = diag( inf*ones( size(Xo) ) );
    end
    if isempty(Pbaro) || all(all(isinf(Pbaro)))
        Pbaro = diag( inf*ones( size(Xbaro) ) );
    end
elseif nargin >= 4,
    Po = diag( inf*ones( size(Xo) ) );
    Pbaro = Po;
end
if nargin >= 6,
    if all(isfield(varargin{6}, {'tru','est'})),
        options = varargin{6};    
        options.est = validateOdtbxOptions(options.est);
        options.tru = validateOdtbxOptions(options.tru);
    else
        options.tru = validateOdtbxOptions(varargin{6});
        options.est = options.tru;
    end

else
    options.tru = setOdtbxOptions('OdeSolvOpts',odeset);
    options.est = options.tru;
end
ncases = getOdtbxOptions(options.est,'MonteCarloCases',1);
niter = getOdtbxOptions(options.est,'UpdateIterations',10);
if nargin >= 7,
    if all(isfield(varargin{7}, {'tru','est'}))
        dynarg = varargin{7};
    else
        dynarg.tru = varargin{7};
        dynarg.est = varargin{7};
    end
elseif nargin >= 4,
    dynarg.tru = [];
    dynarg.est = [];
end
if nargin >= 8,
    if all(isfield(varargin{8}, {'tru','est'}))
        datarg = varargin{8};
    else
        datarg.tru = varargin{8};
        datarg.est = varargin{8};
    end
elseif nargin >= 4,
    datarg.tru = [];
    datarg.est = [];
end

if nargout == 0,
    demomode = true;
else
    demomode = false;
end

%% Reference Trajectory
% Integrate the reference trajectory and associated variational equations
% over the specified time interval.  Assume the first instant is the anchor
% time, and assume the measurements occur on each of the subsequent times.

% Note that if tspan is a 2-vector, then it will be replaced by a new tspan
% as determined by the variable step integrator within the function integ.
[tspan,Xref,Phi,Qd] = integ(dynfun.tru,tspan,Xo,options.tru,dynarg.tru);
[t,Xsref,Phiss] = integ(dynfun.est,tspan,Xbaro,options.est,dynarg.est);
Yref = feval(datfun.tru,tspan,Xref,datarg.tru);
Ybar = feval(datfun.est,tspan,Xsref,datarg.est);
[~,H,R] = ominusc(datfun.tru,tspan,Xref,Yref,options.tru,[],datarg.tru);
[~,Hs,Rhat] = ominusc(datfun.est,tspan,Xsref,Ybar,options.est,[],datarg.est);
% nmeas = size(Yref,1);

% Assign other input variables dependent on tspan, if needed
if nargin >= 9,
    if isa(varargin{9},'function_handle'),
        mapfun = varargin{9}; %TODO
    elseif isa(varargin{9},'numeric') % constant solve-for map
        S = repmat(varargin{9},[1,1,length(tspan)]);
        C = zeros(0,0,length(tspan)); % in case C is not also input 
    end
elseif nargin >= 4,
    S = repmat(eye(size(Po)),[1,1,length(tspan)]);
    C = zeros(0,0,length(tspan));
end
if nargin >= 10, % constant consider map
    C = repmat(varargin{10},[1,1,length(tspan)]);
end


%% Covariance Analysis
% Perform a general covariance analysis linearized about the reference.
% Assume that design values and true values may differ for the initial
% covariance, measurement noise covariance, and process noise covariance.
% Assume that the dynamics and measurement partials, and the process and
% measurement noise covariances, may be time-varying. Assume that linear,
% possibly time-varying, transformations partition the state space into a
% "solve-for" subspace which is to be estimated from the measurements, and
% a "consider" subspace which will not be estimated. Compute the
% contributions due to _a priori_ uncertainty, measurement noise, and
% process noise.  Compute the sensitivity to _a priori_ errors at the
% anchor time. Propagate the true and estimated covariances, and the
% sensitivity matrix, over the specified time span.

%%
% *Solve-For and Consider Mapping*
%
% The mapping of the state-space into solve-for and consider subspaces is
% defined according to
%
% $$ s(t) = S(t) x(t), \quad c(t) = C(t) x(t) $$
%
% $$ M(t) = \Bigl[ S(t);\, C(t) \Bigr], \quad 
% M^{-1}(t) = \Bigl[ \tilde{S}(t),\, \tilde{C}(t) \Bigr]$$
%
% $$ x(t) = \tilde{S}(t) s(t) + \tilde{C}(t) c(t) $$

if ~exist('S','var'),
    [S,C] = feval(mapfun,t,Xref);
end
ns = size(S(:,:,1),1); 
nc = size(C(:,:,1),1); 
n = ns + nc;
lent = length(tspan);
for i = lent:-1:1,
    Minv = inv([S(:,:,i);C(:,:,i)]); 
    Stilde(:,:,i) = Minv(:,1:ns); 
    Ctilde(:,:,i) = Minv(:,ns+1:n); 
end

% Acquire the "use process noise" flag, which defaults to 1 ('yes').
procNoiseFlag = getOdtbxOptions(options.est, 'UseProcNoise', 1);

% If the user has specified that process noise should not be used,
% achieve this by zeroing out the Qd array.
if(procNoiseFlag == 0)
    Qd = 0*Qd;
end

% Check for process noise and issue warning if appropriate
if any(any(any(Qd))),
    nonzeroq = true;
    sizeQtilde = (8*n*lent)^2; % 8 Bytes * n * length(tspan)
    sizeQtilde = sizeQtilde/(2^20); % Convert to MBytes
    if sizeQtilde > 10 % 10 MB
        warning('ESTBAT:bigQtilde',[num2str(sizeQtilde), ...
            ' MBytes required for Qtilde.' ])
        disp('ESTBAT might run really slow unless you have lots of memory.')
        disp('Consider using fewer time samples.')
        disp('You are in the workspace of ESTBAT; type ''return'' to continue,')
        disp('or ''dbquit'' to exit.')
        keyboard
    end
else
    nonzeroq = false;
end

%%
% *Batch Gains*
%
% The batch update can be expressed using the following gain matrices: 
%
% $$ K_i = \Bigl(\hat{P}_{o-}^{-1} + \sum_j \Phi_{ss}'(t_j,t_o) H_s'(t_j) 
% \hat{R}_j^{-1} H_s(t_j) \Phi_{ss}(t_j,t_o) \Bigr)^{-1} \Phi_{ss}'(t_i,t_o) 
% H_s'(t_i) \hat{R}_i^{-1} $$
%
% where
%
% $$ \Phi_{ss}(t_i,t_o) = S(t_i) \Phi(t_i,t_o) \tilde{S}(t_i), \quad
% H_s(t_i) = H(t_i) \tilde{S}(t_i) $$


% Accumulate the estimator's information matrix
J = inv(Pbaro);
for i = 1:lent
    k = find(~isnan(Ybar(:,i)));  % Find measurements that are not NaN
    if ~isempty(k)
        J = J + Phiss(:,:,i)'*Hs(k,:,i)'/(Rhat(k,k,i))*Hs(k,:,i)*Phiss(:,:,i);
    end
end

% Compute the gains
for i = lent:-1:1,
    k = find(~isnan(Ybar(:,i)));
    %K{i} = J\Phiss(:,:,i)'*Hs(k,:,i)'/(Rhat(k,k,i));
    %K{i} = robustls(J,Phiss(:,:,i)'*Hs(k,:,i)'/(Rhat(k,k,i)));
    K{i} = lscov(J,Phiss(:,:,i)'*Hs(k,:,i)'/(Rhat(k,k,i)));
    Ktilde{i} = Stilde(:,:,i)*K{i};
end


%%
% *Batch Update*
%
% $$ \hat{P}_a(t_o^+) = \Bigl(I - \sum_i K_i H_s(t_i) \Phi_{ss}(t_i,t_o)\Bigr)
% \hat{P}_o^- \Bigl(I - \sum_i K_i H_s(t_i) \Phi_{ss}(t_i,t_o)\Bigr)' $$
%
% $$ P_a(t_o^+) = \Bigl(I - \sum_i \tilde{S}(t_i) K_i H(t_i) \Phi(t_i,t_o)\Bigr)
% P_o^- \Bigl(I - \sum_i \tilde{S}(t_i) K_i H(t_i) \Phi(t_i,t_o)\Bigr)' $$
%
% $$ \hat{P}_v(t_o^+) = \sum_i K_i \hat{R}(t_i) K_i', \quad 
% P_v(t_o^+) = \sum_i \tilde{S}(t_i) K_i R(t_i) K_i' \tilde{S}'(t_i)$$
%
% The contribution to the batch estimator's formal variance from process noise is
% zero, since the batch filter does not model process noise; however, if
% there is really process noise present, the then the true variance due to
% process noise is
%
% $$ P_w(t_o^+) = \tilde{\mathbf{K}} \Bigl[ \Upsilon(t_1,t_1), \Upsilon(t_1,t_2), \cdots; 
% \Upsilon(t_2,t_1), \Upsilon(t_2,t_2), \cdots; \cdots\; \Bigr] \tilde{\mathbf{K}}'$$
%
% where, assuming the anchor time is prior to the definitive span,
%
% $$ \Upsilon(t_i,t_j) = H(t_i) \Phi(t_i,t_j) Q_d(t_j,t_o) H(t_j)', \quad
% \tilde{\mathbf{K}} = \Bigl[ \tilde{S}(t_1) K_1, \tilde{S}(t_2) K_2, \cdots\; \Bigr] $$
%
% and
%
% $$ \Upsilon(t_j,t_i) = \Upsilon(t_i,t_j)' $$
%
% It will be convenient below to preserve the intermediate quantities
%
% $$ \tilde{Q}_d(t_i,t_j) = \Phi(t_i,t_j) Q_d(t_j,t_o), \quad
% N(t_i,t_j) = H(t_i) \tilde{Q}_d(t_i,t_j) $$

% Accumulate the coefficients for updating a-priori and measurement noise
% partitions
for i = 1:lent,
    if i == 1,
        ImSKH = eye(n);
        ImKHs = eye(ns);
        Pvo = 0;
        Phatvo = 0;
    end
    k = find(~isnan(Ybar(:,i)));
    ImSKH = ImSKH - Ktilde{i}*H(k,:,i)*Phi(:,:,i);
    ImKHs = ImKHs - K{i}*Hs(k,:,i)*Phiss(:,:,i);
    Pvo = Pvo + Ktilde{i}*R(k,k,i)*Ktilde{i}';
    Phatvo = Phatvo + K{i}*Rhat(k,k,i)*K{i}';
end
% Update a-priori partitions
Pfo = Po; 
Pfo(isinf(Po))=0; %infinite values are set to zero.
Pao = ImSKH*Pfo*ImSKH';
Pbarfo = Pbaro; 
Pbarfo(isinf(Pbaro))=0; %infinite values are set to zero.
Phatao = ImKHs*Pbarfo*ImKHs';
% Build up Qtilde and Upsilon matrices, unless process noise is zero
if ~nonzeroq,
    Pwo = zeros(size(Pao));
else
    for i = lent:-1:1,
        k = find(~isnan(Ybar(:,i)));
        Qtilde{i,i} = Qd(:,:,i);
        Nu{i,i} = H(k,:,i)*Qd(:,:,i);
        Ups{i,i} = Nu{i,i}*H(k,:,i)';
        Gamma{1,i} = Ktilde{1,i}*H(k,:,i);
        for j = i-1:-1:1,
            Qtilde{i,j} = Phi(:,:,i)/Phi(:,:,j)*Qd(:,:,j); 
            Qtilde{j,i} = Qtilde{i,j}'; 
            Nu{i,j} = H(k,:,i)*Qtilde{i,j}; 
            Nu{j,i} = H(k,:,j)*Qtilde{j,i}; 
            Ups{i,j} = Nu{i,j}*H(k,:,j)'; 
            Ups{j,i} = Ups{i,j}'; 
        end
    end
    
    Pwo = cell2mat(Gamma)*cell2mat(Qtilde)*cell2mat(Gamma)';
end

%%
% *Propagation*
%
% Propagate the estimated and true covariances, respectively, over the
% specified time interval, as follows:
%
% $$ \hat{P}_a(t) = \Phi_{ss}(t,t_o) \hat{P}_a(t_o^+) \Phi'_{ss}(t,t_o), \quad
% P_a(t) = \Phi(t,t_o) P_a(t_o^+) \Phi'(t,t_o) $$
%
% $$ \hat{P}_v(t) = \Phi_{ss}(t,t_o) \hat{P}_v(t_o^+) \Phi'_{ss}(t,t_o), \quad
% P_v(t) = \Phi(t,t_o) P_v(t_o^+) \Phi'(t,t_o) $$
%
% $$ P_w(t) = \Phi(t,t_o) P_w(t_o^+) \Phi'(t,t_o) 
% + \Phi(t,t_o) N_d(t) + N_d'(t) \Phi'(t,t_o) + Q_d(t,t_o) $$
% 
% where
%
% $$ N_d(t_k) = -\tilde{\mathbf{K}} N(:,t_k) $$
%
% Note that for propagation to epochs beyond the definitive span (not
% implemented in ESTBAT),
%
% $$ N_d(t) = -\sum_i \tilde{S}(t_i) K_i H(t_i) Q_d(t_i,t_o) \Phi'(t,t_i) $$
%
% and if propagating to epochs prior to the definitive span,
%
% $$ N_d(t) = 0 $$

% Note that Phi(:,:,i) = Phi(ti,to), Qd(:,:,i) = Qd(ti,to), and 
% Phi(:,:,1) = I, Qd(:,:,1) = 0
for i = lent:-1:1,
    Pa(:,:,i) = Phi(:,:,i)*Pao*Phi(:,:,i)'; 
    Pv(:,:,i) = Phi(:,:,i)*Pvo*Phi(:,:,i)'; 
    if nonzeroq
        %Nd = -cell2mat(Ktilde)*cell2mat(Nu(:,i));
        Nd = -cell2mat(Gamma)*cell2mat(Qtilde(:,i));
        Pw(:,:,i) = Phi(:,:,i)*Pwo*Phi(:,:,i)' ...
            + Phi(:,:,i)*Nd + Nd'*Phi(:,:,i)' + Qd(:,:,i); 
    else
        Pw(:,:,i) = Pwo; 
    end
    Phata(:,:,i) = Phiss(:,:,i)*Phatao*Phiss(:,:,i)'; 
    Phatv(:,:,i) = Phiss(:,:,i)*Phatvo*Phiss(:,:,i)'; 
end

%%
% *Sensitivities*
%
% The sensitivity matrix shows the linear sensitivity of the solution
% at the anchor time to mismodeling of the distributions of the _a priori_
% parameters (both solve-fors and considers):
%
% $$ \Sigma_a(t) = S(t) \Phi(t,t_o) \Bigl(I - \sum_{i=1}^k \tilde{S}(t_i) K_i
% H(t_i) \Phi(t_i,t_o)\Bigr) \Bigl[\tilde{S}(t_o), \tilde{C}(t_o) \Bigr] $$
%
% Although it is possible to compute the sensitivities to each particular
% measurement and process noise sample, as follows:
%
% $$ \Sigma_{vk}(t_o) = -K_k, \quad \Sigma_{wk}(t_o) = -K_k H(t_k) $$
%
% this does not appear to be particularly useful.  Instead, suppose R and Rhat
% have the same structure, but differ only by a scalar multiplier, i.e., 
% R = r*Ro and Rhat = rhat*Ro (for example, let Ro = I).  Then, 
%
% $$\Delta P_v = S P_v S' - \hat{P}_v = K R_o K' (r - \hat{r}). $$
%
% In this case, if one chooses (r-rhat) = 1, delta P_v will represent the
% sensitivity to measurement noise mismodeling across the entire data span.
% Similarly, when Q = q*Qo, q will factor out of the process noise
% partition, so that if one chooses q = 1, delta P_w (= P_w since the
% batch has no process noise) will represent the sensitivity to process
% noise mismodeling across the entire interval of interest.

Sigma_ao = ImSKH*[Stilde(:,:,1), Ctilde(:,:,1)]; 
for i = lent:-1:1,
    Sigma_a(:,:,i) = S(:,:,1)*Phi(:,:,i)*Sigma_ao; 
end
Sigma_ao = S(:,:,1)*Sigma_ao;

%% Variance Sandpiles
% Generate "variance sandpiles," which are stacked area charts showing the
% the time series of each solve-for variance's contribution from _a
% priori_ error variance, measurement noise variance, and process noise
% variance.  This can be done is several ways.  The true variance and the
% formal variance are
%
% $$ P = P_a + P_v + P_w, \quad \hat{P} = \hat{P}_a + \hat{P}_v $$
%
% and the delta variances are
%
% $$ \Delta P_a = S P_a S' - \hat{P}_a, \quad  \Delta P_v = S P_v S' -
% \hat{P}_v, \quad \Delta P_w = S P_w S' $$
%
% When all the delta variances are positive, the sandpile should show the
% formal variance, and the deltas due to each component.  When all the
% deltas are negative, the sandpile should show the true variance, and
% negatives of the deltas.  Otherwise, plot the components of the true
% variance as a positive sandpile, and the components of the formal
% variance as a negative sandpile, and relabel the negative y-axes to
% indicate this.

P = Pa + Pv + Pw;
Phat = Phata + Phatv;
Phatw = zeros(size(Phat));
for i = lent:-1:1,
    dPa(:,:,i) = S(:,:,i)*Pa(:,:,i)*S(:,:,i)' - Phata(:,:,i); 
    dPv(:,:,i) = S(:,:,i)*Pv(:,:,i)*S(:,:,i)' - Phatv(:,:,i); 
    dPw(:,:,i) = S(:,:,i)*Pw(:,:,i)*S(:,:,i)'; 
end

% Compute the true measurement error covariance Pdyt
[~,~,R,Pdyt] = ominusc(datfun.tru,tspan,Xref,Yref,options.tru,P,datarg.tru);

% NOTE: For the demomode examples plotted below, the pre- and
% post-multiplication of P_a, P_v, and P_w by S and S',
% respectively, have been ignored for simplicity since the
% solve-for states are the first ns states.

if demomode,
    for i = 1:ns,
        figure(i)
        clf
        varpiles(tspan,...
            squeeze(dPa(i,i,:)),...
            squeeze(dPv(i,i,:)),...
            squeeze(dPw(i,i,:)),...
            squeeze(Pa(i,i,:)),...
            squeeze(Pv(i,i,:)),...
            squeeze(Pw(i,i,:)),...
            squeeze(Phata(i,i,:)),...
            squeeze(Phatv(i,i,:)),...
            squeeze(Phatw(i,i,:)),...
            squeeze(P(i,i,:)),...
            squeeze(Phat(i,i,:)))
    end
end

%% Sensitivity Mosaics
% Generate "sensitivity mosaics," which are checkerboard plots of the
% sensitivity matrices.  For some reason, Matlab's pcolor function does not
% plot the final row and column, so append an extra row and column to get
% the correct plot.  Initially plot the sensitivity at the anchor time,
% and put up a slider that lets the user scan through sensitivities over
% the batch.
if demomode,
    lastfig = ns;
    figure(lastfig+1)
    hold off
    pcolor(eye(ns+1,ns)*Sigma_ao*eye(n,n+1))
    set(gca,'xtick',1:n,'ytick',1:ns)
    xlabel('{\it A Priori} State Index')
    sa = uicontrol(gcf,'style','slider',...
        'max',tspan(end),'min',tspan(1),...
        'value',tspan(1),...
        'sliderstep',[mean(diff(tspan))/tspan(end-1),0.5],...
        'units','normalized','position',...
        get(gca,'position')*[1 0 0 0;0 1 0 -.1;0 0 1 0;0 0 0 .1]'); 
    ca = @(h,e) pcolor(eye(ns+1,ns)*...
        Sigma_a(:,:,round(get(sa,'value')))*eye(n,n+1));
    set(sa,'callback', ca)
    ylabel('Solve-For State Index')
    set(gca,'ydir','rev','xaxisloc','top')
    axis equal
    colorbar
    title('Sensitivity Mosaic')
    hold on
end
%% Monte Carlo Simulation
% Always perform at least one actual simulation as a check against
% linearization problems.  Generate random deviations from the reference as
% initial conditions for each monte carlo case.  Integrate each deviated
% case, and use this as truth for measurement simulation and estimation
% error generation.  Iterate the batch estimator, re-linearizing each time,
% until a convergence tolerance or an iteration limit is reached.  Do this
% after plotting the covariance results, so the user can terminate the run
% if obvious problems occur, since the simulation may be slow, especially
% if a lot of monte carlo cases are running.

% Generate random deviations from the reference trajectory and simulate
% measurements from the deviated trajectories.  Remember that Phi(:,:,i) =
% Phi(ti,to), Qd(:,:,i) = Qd(ti,to), and Phi(:,:,1) = I, Qd(:,:,1) = 0.
% Since Qd goes from to to ti, we can't use it to generate a time series
% for wd(ti,to) at time ti, because it would not generate the proper
% correlations at times prior to ti.  However, the matrix Qtilde
% explicitly does model these correlations.  Note that the rows and columns
% of Qtilde corresponding to the anchor time are zero, and since covsmpl
% uses the Cholesky decomposition, we have to handle this case separately.

% Check some estimator options
eopts = chkestopts(options.est,ncases);

for j = ncases:-1:1,
    xo = covsmpl(Po, 1, eopts.monteseed(j));
    if nonzeroq,
        wd{j} = [zeros(size(xo)),...
            reshape(covsmpl(cell2mat(Qtilde(2:end,2:end))),n,[])]; 
    else
        wd{j} = zeros(n,lent); 
    end
    [~,xdum] = integ(dynfun.tru,tspan,Xo+xo,options.tru,dynarg.tru);
    for i = lent:-1:1,
        %x = Phi(:,:,i)*xo + wd{j}(:,i);
        X{j}(:,i) = xdum(:,i) + wd{j}(:,i); 
    end
    Y{j} = feval(datfun.tru,tspan,X{j},datarg.tru) + covsmpl(R); 
end

Phato = cell(ncases,1);
Xhato = cell(ncases,1);

% Run the batch estimator on the measurements generated above.
Xsref0 = Xsref(:,1); 
tol = 0.1*det(Pao+Pvo+Pwo)^(1/2/n);%ns*sqrt(max(Rhat(Rhat>0)));

% From Ravi: Find a better way to show this! It litters the output.
% disp('sqrt(diag(Phatao+Phatvo)) = ')
% disp(sqrt(diag(Phatao+Phatvo))')
% disp('sqrt(diag(Pao+Pvo+Pwo)) = ')
% disp(sqrt(diag(Pao+Pvo+Pwo))')

parfor j = 1:ncases,
    Dxo = Inf;
    iter = 0;
    Xhato{j} = Xsref0;
    while Dxo > tol
        [tj,Xbar,Phiss] = integ(dynfun.est,tspan,Xhato{j},options.est,dynarg.est); %#ok<PFBNS>
        lentj = length(tj);
        J = inv(Pbaro);
        dY = NaN(size(Y{j}));
        [dy,Hs,Rhat] = ominusc(datfun.est,tspan,Xbar,Y{j},options.est,[],datarg.est); %#ok<PFBNS>
        for i = 1:lentj
            k = find(~isnan(Y{j}(:,i)));  % Find measurements that are not NaN
            if ~isempty(k)
                dY(k,i) = dy(k,i);
                J = J + Phiss(:,:,i)'*Hs(k,:,i)'/(Rhat(k,k,i)) ...
                    *Hs(k,:,i)*Phiss(:,:,i);
            end
        end
        fullrank = (prod(svd(J))>0);
        if ~fullrank
            error('ESTBAT:notobserv',['System is not observable.  ',...
                'Rank of Normal Matrix = ', num2str(rank(J))])
        end 
        dxo = 0;
        for i = 1:lentj,
            if i == 1,
                ImKHsj = eye(ns);
                Pbarfoj = Pbaro;
                Pbarfoj(isinf(Pbaro))=0; %infinite values are set to zero.
                Phato{j} = 0;
            end
            k = find(~isnan(Y{j}(:,i)));
            %Kj = robustls(J,Phiss(:,:,i)'*Hs(k,:,i)'/(Rhat(k,k,i)));
            Kj = lscov(J,Phiss(:,:,i)'*Hs(k,:,i)'/(Rhat(k,k,i)));
            ImKHsj = ImKHsj - Kj*Hs(k,:,i)*Phiss(:,:,i);
            Phato{j} = Phato{j} + Kj*Rhat(k,k,i)*Kj';
            dxo = dxo + Kj*dY(k,i);
        end
        Phato{j} = Phato{j} + ImKHsj*Pbarfoj*ImKHsj';
        
        % From Ravi: Find a better way to show this! It litters the output.
%         disp(['Iteration number: ',num2str(iter)])
%         disp('dxo = ')
%         disp(dxo')
%         disp('sqrt(diag(Phato{j})) = ')
%         disp(sqrt(diag(Phato{j}))')
        Xhato{j} = Xhato{j} + dxo;
        if iter < niter
            iter = iter + 1;
            Dxo = norm(dxo);
        else
            warning('ESTBAT:maxit','Max iterations reached in estbat');
            break
        end
    end
end

%% Estimation Error Ensemble
% Generate the time series of estimation errors and residuals for each
% case.  Due to nonlinearities, the formal variance could be different for
% each case, so generate the time series of these as well.  Use estval to
% plot these data if no output arguments are supplied.

clear t Phat
for j = ncases:-1:1,
    [t{j},Xhat{j},Phiss] = integ(dynfun.est,tspan,Xhato{j},options.est,dynarg.est); 
    for i = length(t{j}):-1:1,
        pji = Phiss(:,:,i)*Phato{j}*Phiss(:,:,i)';
        Phat{j}(:,i) = scrunch((pji+pji')/2); % avoids symmetry warnings
        e{j}(:,i) = Xhat{j}(:,i) - S(:,:,i)*X{j}(:,i); 
    end
    [y{j},~,~,Pdy{j}] = ominusc(datfun.est,t{j},Xhat{j},Y{j},options.est,unscrunch(Phat{j}),datarg.est); 
end
if demomode,
    estval(t,e,Phat,scrunch(P),gcf) % ESTVAL expects covs to be scrunched
    disp('You are in the workspace of ESTBAT; type ''return'' to exit.')
    keyboard
end

if nargout >= 3,
    varargout{1} = t;
    varargout{2} = Xhat;
    varargout{3} = Phat;
end
if nargout >= 4,
    varargout{4} = e;
end
if nargout >= 5,
    varargout{5} = y;
end
if nargout >= 6,
    varargout{6} = Pa;
    varargout{7} = Pv;
    varargout{8} = Pw;
    varargout{9} = Phata;
    varargout{10} = Phatv;
    varargout{11} = Phatw;
end
if nargout >= 12,
    varargout{12} = Sigma_a;
end
if nargout >= 13
    varargout{13} = Pdy;
end 
if nargout >= 14
    varargout{14} = Pdyt;
end 
end % function

% function x = robustls(A,b)
% % More robust least-squares solution to Ax = b.  This is based on the help
% % for the QR function, which shows how "the least squares approximate
% % solution to A*x = b can be found with the Q-less qr decomposition and one
% % step of iterative refinement."
% R = triu(qr(A));
% x = R\(R'\(A'*b));
% r = b - A*x;
% e = R\(R'\(A'*r));
% x = x + e;
% end