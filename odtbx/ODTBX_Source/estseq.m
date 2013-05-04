function varargout = estseq(varargin)
% ESTSEQ  Sequential Estimator.
%
%   [T,X,P] = ESTSEQ(DYNFUN,DATFUN,TSPAN,X0,P0) with TSPAN = [T0 TFINAL]
%   integrates the system of differential equations x' = f(t,x) from T0 to
%   TFINAL with initial conditions X0, then at TFINAL updates x with the
%   measurement generated by y = h(t,x) + v using a Kalman gain based on
%   propagation of the covariance matrix P0.  To obtain updates at multiple
%   times T1, T2, ..., TFINAL, use TSPAN = [T0 T1 T2 ... TFINAL].
%
%   Function [F,A,Q]=DYNFUN(T,X,options) must return a column vector 
%   corresponding to f(t,x). If DYNFUN is "vectorized," then f(t,x) must be
%   a 2-D array with each column corresponding to f(t(i),x(t(i)). Function 
%   DYNFUN(T,X) must return an additional output if called with two output
%   arguments, which may either be a matrix corresponding to A(t), or else 
%   an empty matrix, in which case INTEG will numerically compute A(t) with
%   NUMJAC. If A(t) is supplied, it must be a 3-D array for the vectorized
%   case, with each "slice" corresponding to A(t(i)).  To include process
%   noise, DYNFUN must return the process noise spectral density matrix, Q
%   = E[ww'], where x' = f(t,x) + w, as an additional output.  If DYNFUN is
%   vectorized, then Q must be a 3-D array, with each "slice" corresponding
%   to Q(t(i)).
%
%   Function [h,H,R]=DATFUN(T,X,options) must return a column vector 
%   corresponding to h(t,x), and two additional outputs corresponding to 
%   the measurement partials, H(t) = dh(t,x)/dx, and the measurement noise 
%   covariance, R = E[vv'], where y = h(t,x) + v.  As an alternate to 
%   supplying H(t), DATFUN may return an empty matrix as its second output, 
%   in which case ESTINV will numerically compute H(t) using NUMJAC. If 
%   DATFUN is "vectorized," then h(t,x) must return as its first output a 
%   2-D array with each column corresponding to h(t(i),x(t(i)); its next 
%   two outputs must be 3-D arrays with each "slice" corresponding to 
%   H(t(i)) and R(t(i)), respectively.
%
%   The rows in the solution array X correspond to times returned in the 
%   column vector T, which are chosen by the integrator.  The rows in the 
%   solution covariance array P correspond to the unique lower triangular 
%   elements of P at the times T, appended by row from column 1 to the main 
%   diagonal.  The Ith row may be reformed into a matrix using 
%   UNSCRUNCH(P(I,:)).
%
%   [T,X,P] = ESTSEQ(DYNFUN,DATFUN,TSPAN,X0,P0,OPTIONS) performs as above
%   with default properties replaced by values in OPTIONS, an argument
%   created with the SETODTBXOPTIONS function.  See ODTBXOPTIONS for
%   details. Commonly used options allow one to specify parameters or
%   features of the estimator, force model, and measurment model.  One of
%   the estimator parameters is 'SchmidtKalman'.  This is the flag to use
%   the Schmidt Kalman filter instead of the standard Kalman filter in
%   ESTSEQ.
%   Note that as of ODTBX R2013a, OPTIONS can be either a standard
%   ODTBXOPTIONS structure, or a struct of two ODTBXOPTIONS structures that
%   are used separately for truth and estimated computations. The latter
%   method is achieved by settings OPTIONS as a struct:
%      >> options.tru = setOdtbxOptions(...);
%      >> options.est = setOdtbxOptions(...);
%      >> [...] = estseq(..., options, ...);
%   Using this method, all options common to truth and estimated
%   computations are taken from the options.est structure, EXCEPT for the
%   'Refint' option, which is taken from the options.tru structure.
%
%   [T,X,P] = ESTSEQ(DYNFUN,DATFUN,TSPAN,X0,P0,OPTIONS,DYNARG,DATARG)
%   passes DYNARG to DYNFUN and DATARG to DATFUN as DYNFUN(T,X,DYNARG) and
%   DATFUN(T,X,DATARG), respectively.  Use OPTIONS = [] as a place holder
%   if no options are set.
%
%   [T,X,P] = ESTSEQ(DYNFUN,DATFUN,TSPAN,X0,P0,OPTIONS,DYNARG,DATARG,S,C)
%   passes in solve-for and consider mapping matrices, S and C,
%   respectively.  These matrices partition the state into a solve-for
%   partition, S*x, and a consider partition, C*x.  Only parameters in the
%   former partition will be updated from the meaurements.  Use [] as a 
%   place holder for OPTIONS, DYNARG, and/or DATARG as necessary if these 
%   inputs are not required.  S and C can be 2-D or 3-D arrays.  If 3-D, 
%   the 3rd dimension corresponds to the time vector. However, time-
%   varying S and C are currently not implemented; therefore, constant S 
%   and C corresponding to the first time vector will be used.
%
%   To handle the different dimensions of the full state vs. the solve-
%   for and consider partitions, the user can either design DYNFUN and 
%   DATFUN to check for this, or specify DYNFUN and/or DATFUN as 
%   structures, whose fields are *.tru and *.est. The function specified 
%   in *.tru will be used to evaluate the full state, and the one in 
%   *.est will be used for the solve-for partition.  This is also a way 
%   to specify differences between the true and the estimator models of the
%   dynamics and the measurement data.  Similar conventions may be used 
%   for X0, P0, DYNARG, and DATARG, i.e. X0.Xo and X0.Xbaro, P0.Po and 
%   P0.Pbaro, DYNARG.tru and DYNARG.est, DATARG.tru and DATARG.est. 
%
%   [T,X,P] = ESTSEQ(RESTARTRECORD,TSPAN) reinitializes the filter with
%   the parameters stored in the RESTARTRECORD structure during
%   a previous run.  RESTARTRECORD is an optional output of ESTSEQ.      
%
%   [T,X,P,E] = ESTSEQ(DYNFUN,DATFUN,TSPAN,X0,P0,...) also returns the
%   estimation errors, E.
%
%   [T,X,P,E,DY,PA,PV,PW,PHATA,PHATV,PHATW] = ESTSEQ(...) returns the 
%   innovations, DY, and several addditional covariance matrices: PA, PV, 
%   and PW are the true covariances that arise only from the true  
%   _a priori_ covariance, the true measurement noise covariance, and the 
%   true process noise covariance, respectively;  PHATA, PHATV, PHATW are 
%   the estimator's covariances that arise only from the design values of 
%   the  _a priori_ covariance, the measurement noise covariance, and the 
%   process noise covariance.
%
%   [T,X,P,E,DY,PA,PV,PW,PHATA,PHATV,PHATW,SIGSA,EFLAG] = ESTSEQ(...) also
%   returns SIGSA, the sensitivity matrix of the solve-for states at each 
%   time step, as well as EFLAG, the array of edit flag values for all 
%   cases for all measurement types for all times. The edit flags may have 
%   the following values:
%
%       0   = Measurement was rejected (based on the edit ratio settings)
%       1   = Measurement was checked and passed the edit ratio test
%       2   = Measurement was forced to be accepted (based on edit flag
%             settings)
%
%   [T,X,P,E,DY,PA,PV,PW,PHATA,PHATV,PHATW,SIGSA,EFLAG,PDY,PDYT] = ESTSEQ(...) 
%   also returns the formal and the true covariance of the measurment 
%   innovations DY, where the former is computed from the Monte Carlo 
%   simulation and the latter is computed once with respect to the true 
%   reference states and measurements.
%
%   If multiple monte-carlo cases are specified using SETODTBXOPTIONS, 
%   this is capable of running the monte-carlo cases in parallel.  Simply
%   open a pool of parallel workers using 'matlabpool' and estseq will
%   utilize them.  The only contraints placed on the caller when running
%   monte-carlo cases in parallel are:
%    1. the dynfun and datafun functions must not retain state that later 
%       monte-carlo runs will rely on
%    2. any Java classes used must be serializable
%    3. any variables that are used in the dynfun or datafun functions but
%       are setup before the call to estseq must appear somehwhere in the 
%       setup code (e.g. setting up a variable by loading it from a file 
%       will assign it a value without the variable name ever appearing in 
%       the code - this will cause an error in parallel execution)
%
%   [T,X,P,E,DY,PA,PV,PW,PHATA,PHATV,PHATW,SIGSA,EFLAG,PDY,PDYT,...
%       PM,PHATM] = ESTSEQ(...) also returns the true and formal covariance
%   matrix partitions associated with external noise sources (ie maneuver
%   execution error). External noise sources are added by modifying the 
%   RESTARTRECORD structure.
%
%   [T,X,P,E,DY,PA,PV,PW,PHATA,PHATV,PHATW,SIGSA,EFLAG,PDY,PDYT,...
%       PM,PHATM,RESTARTRECORD] = ESTSEQ(...) also returns a RESTARTRECORD 
%   structure that contains the necessary parameters to restart ESTSEQ at 
%   time TFINAL.  The RESTARTRECORD can be used to manipulate state, 
%   covariance, and filter parameters outside of ESTSEQ and continue 
%   analysis in a subsequent run.
%
%   Example
%      Given xdot = pr2bp(t,x,mu), [y,H,R] = range2d(t,x,sig):
%         estseq(@pr2bp,@range2d,tspan,x0,P0,[],mu,sig)
%         [t,x,P] = estseq(@pr2bp,@range2d,tspan,x0,P0,[],mu,sig)
%         estsol = estseq(@pr2bp,@range2d,tspan,x0,P0,[],mu,sig)
%      With opts = setOdtbxOptions('OdeSolver',@ode45,...):
%         estseq(@pr2bp,@range2d,tspan,x0,P0,opts,mu,sig)
%
%   keyword: Estimation,
%
%   See also
%      options handling:      ODTBXOPTIONS, SETODTBXOPTIONS,
%                             GETODTBXOPTIONS
%      evaluating solutions:  ESTVAL
%      other ODEAS filters:   ESTBAT
%      other ODEAS utilties:  INTEG, OBSERV
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
% 2009/01/13 Sun Hur-Diaz   Added an option to use the Schmidt-Kalman
%                           filter
% 2009/06/30 Sun Hur-Diaz   Pre-allocated additional matrices to improve 
%                           speed and remove sidebar warnings
% 2009/09/14 Sun Hur-Diaz   Corrected the initialization of the estimator
%                           states in the Monte Carlo simulation
% 2009/09/25 Sun Hur-Diaz   Save measurement innovations covariance(s)  
%                           for post-processing
% 2009/10/13 Sun Hur-Diaz   Added a check for NaN in measurements and set
%                           the corresponding elements of K to zero in the
%                           covariance analysis section of the code
% 2009/10/29 Kevin Berry    Added a check for NaN measurements to the
%                           inputs to kalmup
% 2010/02/23 Sun Hur-Diaz   Set isel to all measurements for general
%                           vectorized measurement update
% 2010/02/24 John Gaebler   Edited help section. Removed warnings 
%                           (mostly replaced junk output with '~'). 
%                           Added ominusc to measurement call allowing 
%                           numerical computation of H.
% 2010/03/15 Sun Hur-Diaz   Replaced rk4 and covprop with integ calls for
%                           more accurate time propagation of states and
%                           covariances
% 2010/10/07 K Getzandanner Implemented RESTARTRECORD functionality
% 2012-08-28 R. Mathur      Extracted regression test
% 2013-05-02 R. Mathur      Fully extracted regression test to estseq_test
%                           Added ability to specify separate truth & estimated
%                           options structures for the options input.

%% ESTSEQ: Sequential Estimator
%
% ESTSEQ is the primary sequential estimator for OD Toolbox.  The original
% version was a fairly slow Kalman estimator of the sort described Tapley,
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
% estbat's version, a private function.
%
% The full self-test has been extracted to estseq_test.m to conform to
% the new regression testing framework.
%
% If there are no output arguments, then plot the results of a particular
% input as a demo.

if(nargin < 2)
    error('estseq no longer supports direct regression testing. Please use estseq_test.');
end

if nargin == 2,
    restart = 1;
    restartRecord = varargin{1};
    Xmco = restartRecord.Xo;
    Xhatmco = restartRecord.Xhato;
    Xo = restartRecord.Xrefo;
    Xbaro = restartRecord.Xsrefo;
    Phatmco = restartRecord.Phato;
    Pao = restartRecord.Pao;
    Pvo = restartRecord.Pvo;
    Pwo = restartRecord.Pwo;
    Pmo = restartRecord.Pmo;
    Phatao = restartRecord.Phatao;
    Phatvo = restartRecord.Phatvo;
    Phatwo = restartRecord.Phatwo;
    Phatmo = restartRecord.Phatmo;
    Sig_ao = restartRecord.Sig_ao;
    dynfun = restartRecord.dynfun;
    datfun = restartRecord.datfun;
    dynarg = restartRecord.dynarg;
    datarg = restartRecord.datarg;
    options = restartRecord.options;
    S = restartRecord.S;
    C = restartRecord.C;
    tspan = varargin{2};
    tspan = tspan(:)';
else 
    restart = 0;
end
if nargin >= 5,
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
    tspan = tspan(:)';
    if isstruct(varargin{4}),
        Xo = varargin{4}.Xo;
        Xbaro = varargin{4}.Xbaro;
    else
        Xo = varargin{4};
        Xbaro = varargin{4};
    end
    if isstruct(varargin{5}),
        Po = varargin{5}.Po;
        Pbaro = varargin{5}.Pbaro;
    else
        Po = varargin{5};
        Pbaro = varargin{5};
    end
    if isempty(Po) || isempty(Pbaro)
        error('Initial covariance must be set!');
    end
elseif nargin > 2,
    error('There must be at least 5 inputs! (dynfun,datfun,tspan,Xo,Po)');
end
if nargin >= 6,
    if all(isfield(varargin{6}, {'tru','est'})),
        options = varargin{6};
    else
        options.tru = varargin{6};
        options.est = options.tru;
    end
elseif nargin ~= 2,
    options.tru = setOdtbxOptions('OdeSolvOpts',odeset);
    options.est = options.tru;
end
upvec = getOdtbxOptions(options.est,'UpdateVectorized',1);
ncases = getOdtbxOptions(options.est,'MonteCarloCases',1);
niter = getOdtbxOptions(options.est,'UpdateIterations',1);
refint = getOdtbxOptions(options.tru,'refint',3); % Applies to truth integrator

if nargin >= 7,
    if all(isfield(varargin{7}, {'tru','est'}))
        dynarg = varargin{7};
    else
        dynarg.tru = varargin{7};
        dynarg.est = varargin{7};
    end
elseif nargin >= 5,
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
elseif nargin >= 5,
    datarg.tru = [];
    datarg.est = [];
end
% TODO: Need to make sure having 3-D C matrix won't mess up Schmidt-Kalman option
if nargin >= 9,
    if isa(varargin{9},'function_handle'),
        mapfun = varargin{9}; %#ok<NASGU> %TODO
    elseif isa(varargin{9},'numeric') % constant solve-for map
        S = varargin{9};
        C = []; %zeros(0,0,length(tspan)); % in case C is not input, solve for all states
    end
elseif nargin >= 5, % If S & C not input, solve for all states
    S = eye(size(Po));
    C = []; %zeros(0,0,length(tspan));
end
if nargin >= 10, % constant consider map
    C = varargin{10}; %repmat(varargin{10},[1,1,length(tspan)]);
end
ischmidt = getOdtbxOptions(options.est,'SchmidtKalman',0);

if nargout == 0,
    demomode = true;
else
    demomode = false;
end

%% Reference Trajectory
% Integrate the reference trajectory and associated variational equations
% over the specified time interval.  Add intermediate sample points between
% each measurement so as to see the effects of the updates.

lents = length(tspan);
if refint < 0 % Variable step integrator to determine intermediate points
    xinit     = Xo;
    tint      = NaN(1,lents*100);
    Xref      = NaN(length(Xo),lents*100);
    tint(1)   = tspan(1); % Time vector including intermediate points
    Xref(:,1) = Xo;      % True states at measurement points tspan only
    ind = 1;
    for i = 1:lents-1
        [ti,xi] = integ(dynfun.tru,tspan(i:i+1),xinit,options.tru,dynarg.tru);
        len = length(ti);
        tint(ind+1:ind+len-1) = ti(2:end)';
        Xref(:,ind+1:ind+len-1) = xi(:,2:end);
        xinit = xi(:,end);
        ind = ind+len-1;
    end
    tint = tint(1:ind);
    Xref = Xref(:,1:ind);
else
    tint = refine(tspan,refint);
    [~,Xref] = integ(dynfun.tru,tint,Xo,options.tru,dynarg.tru);
end
lenti = length(tint);
[~,Xsref] = integ(dynfun.est,tint,Xbaro,options.est,dynarg.est);

% Indices within tint that point back to tspan, i.e., tint(ispan)=tspan
[~,ispan] = ismember(tspan,tint,'legacy');

% JAG replaced original measurement calls with code below which
%   allows numerical computation of H with numjac.m within ominusc if H is 
%   not provided by datfun.
Yref = feval(datfun.tru,tspan,Xref(:,ispan),datarg.tru);
Ybar = feval(datfun.est,tspan,Xsref(:,ispan),datarg.est);
[~,Href,R] = ominusc(datfun.tru,tspan,Xref(:,ispan),Yref,options.tru,[],datarg.tru);
[~,Hsref,Rhat] = ominusc(datfun.est,tspan,Xsref(:,ispan),Ybar,options.est,[],datarg.est);
m = size(Ybar,1);

nmeas = m;
%% Time tag arrays
% Compute a vector of time tags that account for updates (and possible
% iterations) at each measurement time.

% Accounts for updates/iterations
titer = NaN(1,lenti+lents*(niter));
titer(1:niter+1) = tint(1)*ones(1,niter+1);
ind = niter+1;
for i = 2:lents
    delt = [tint(ispan(i-1)+1:ispan(i)-1) ...
             repmat(tint(ispan(i)),1,niter+1)];
    ldt = length(delt);
    titer(ind+1:ind+ldt) = delt;
    ind = ind+ldt;
end
titer = titer(1:ind);
lentr = length(titer);

% Find indices within titer that point back to tint
[~,iint] = ismember(tint,titer,'legacy');

%% Covariance Analysis
% Perform a general covariance analysis linearized about the reference.
% Assume that design values and true values may differ for the initial
% covariance (Pa), measurement noise covariance (Pv), and process noise 
% covariance (Pw).  Assume that the dynamics and measurement partials, and 
% the process and measurement noise covariances, may be time-varying. 
% Assume that linear, possibly time-varying, transformations partition the 
% state space into a "solve-for" subspace which is to be estimated from the 
% measurements, and a "consider" subspace which will not be estimated. 
% Compute the contributions due to _a priori_ uncertainty, measurement 
% noise, and process noise.  Compute the sensitivity to _a priori_ errors, 
% both solve-for and consider.


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

if ~exist('mapfun','var'),
    ns = size(S(:,:,1),1);
    nc = size(C(:,:,1),1);
    if lentr > 1,
        if size(S,3) > 1 || size(C,3) > 1,
            disp('For time-varying S & C, ESTSEQ requires input of mapfun (currently not implemented).')
            disp('Replicating S(:,:,1) & C(:,:,1) instead.')
            S = S(:,:,1);
            C = C(:,:,1);
        end
        S = repmat(S,[1,1,lentr]);
        if isempty(C),
            C = zeros(0,0,lentr);
        else
            C = repmat(C,[1,1,lentr]);
        end
    end
else % TODO: implement mapfun
    error('mapfun not implemented in this release')
end
n = ns + nc;

%% Perform linear covariance analysis using Kalman Filter methods

if restart
    Po = Pao + Pvo + Pwo + Pmo;
    Pbaro = Phatao + Phatvo + Phatwo + Phatmo;
    
    % Here, the entire options structure is passed in, even if it has
    % separate truth & estimated components. lincov_kf will sort that out.
    [P,Pa,Pv,Pw,Pm,Phata,Phatv,Phatw,Phatm,Sig_a,Pdyt]=lincov_kf(...
        tspan,tint,titer,niter,S,C,Po,Pbaro,Xref,Href,Yref,R,Xsref,Hsref,...
        Ybar,Rhat,dynfun,dynarg,demomode,ischmidt,options,...
        Pao,Pvo,Pwo,Pmo,Phatao,Phatvo,Phatwo,Phatmo,Sig_ao);
else
    [P,Pa,Pv,Pw,Pm,Phata,Phatv,Phatw,Phatm,Sig_a,Pdyt]=lincov_kf(...
        tspan,tint,titer,niter,S,C,Po,Pbaro,Xref,Href,Yref,R,Xsref,Hsref,...
        Ybar,Rhat,dynfun,dynarg,demomode,ischmidt,options);
end

for j = lentr:-1:1,
    Sig_sa(:,:,j) = S(:,:,j)*Sig_a(:,:,j); 
end


%% Monte Carlo Simulation
% Always perform at least one actual simulation as a check against
% linearization problems.  Generate random deviations from the reference as
% initial conditions for each monte carlo case.  Integrate each deviated
% case, and use this as truth for measurement simulation and estimation
% error generation.  Do this after plotting the covariance results, so the
% user can terminate the run if obvious problems occur, since the
% simulation may be slow, especially if a lot of monte carlo cases are
% running.

% First check consistency of the estimator opts
eopts = chkestopts(options.est,ncases,m);

% Pre-allocate arrays that need to be filled in forward-time order (the
% rest can be fully allocated when created).
[t,X,Xhat,Phat,y,Y,e,dPhat,de,eflag,Pdy] = deal(cell(1,ncases));

% Minimally allocate Xmco for the parfor loop, if needed.
if ~restart
    Xmco = deal(cell(1,ncases));
end

% Generate true states for each case
parfor j = 1:ncases,
    
    % Allocate each variable cell used in the parfor initially with NaNs.
    % (FYI, If all accesses in the parfor occur via the same X{j} then the 
    % parfor only moves the X{j} data in and out of the parfor.)
    X{j} = NaN(n,lenti);
    Y{j} = NaN(m,lents);     % True measurements
    
    for i = 1:lents,
        if i == 1,
            if restart
                X{j}(:,1) = Xmco(:,j);
            else
                X{j}(:,1) = Xref(:,1) + covsmpl(Po, 1, eopts.monteseed(j));
            end
        else
            for k = ispan(i-1):ispan(i)-1
                [~,xdum,~,sdum] = integ(dynfun.tru,tint(k:k+1),X{j}(:,k),options.tru,dynarg.tru);
                X{j}(:,k+1) = xdum(:,end) + covsmpl(sdum(:,:,end));
            end
        end

        Y{j}(:,i) = feval(datfun.tru,tspan(i),X{j}(:,ispan(i)),datarg.tru)+covsmpl(R(:,:,i));
 
    end

end

% Run Kalman Filter on the measurements generated above

% Minimally allocate these variables for the parfor loop, if needed.
if ~restart
    Xhatmco = NaN(n,ncases);
    Phatmco = NaN(n,n,ncases);
end

parfor j = 1:ncases,
    
    % Allocate each variable cell used in the parfor initially with NaNs.
    % (FYI, If all accesses in the parfor occur via the same X{j} then the 
    % parfor only moves the X{j} data in and out of the parfor.)
    Xhat{j} = NaN(length(Xbaro),lentr);
    Phat{j} = NaN([size(Pbaro),lentr]);
    y{j} = NaN(m,lentr);     % Measurement innovations
    eflag{j} = NaN(m,lentr);
    Pdy{j} = NaN(m,m,lentr); % Measurement innovations covariance

    if restart
        Xhat{j}(:,1) = Xhatmco(:,j);
        Phat{j}(:,:,1) = Phatmco(:,:,j);
    else
        Xhat{j}(:,1) = Xbaro;    % The filter i.c. is always the same
        Phat{j}(:,:,1) = Pbaro;
    end

    for i = 1:lents,
        
        % Time update
        if i == 1,
            thisint = 1;
        else
            thisint = iint(ispan(i-1)):iint(ispan(i))-niter; %#ok<PFBNS>
            [~,xdum,phidum,sdum] = integ(dynfun.est,titer(thisint),Xhat{j}(:,thisint(1)),options.est,dynarg.est);%#ok<PFBNS>
            if length(thisint) == 2 % This is because for time vector of length 2, ode outputs >2
                xdum = [xdum(:,1) xdum(:,end)];
                phidum(:,:,2) = phidum(:,:,end);
                sdum(:,:,2) = sdum(:,:,end);
            end
            Xhat{j}(:,thisint) = xdum;
            for k = 2:length(thisint)
                sdum(:,:,k) = (sdum(:,:,k) + sdum(:,:,k)')/2;
                Phat{j}(:,:,thisint(k)) = phidum(:,:,k)*Phat{j}(:,:,thisint(1))*phidum(:,:,k)' + sdum(:,:,k);
                Phat{j}(:,:,thisint(k)) = (Phat{j}(:,:,thisint(k)) + Phat{j}(:,:,thisint(k))')/2;
            end
        end
        
        
        isel = 1:nmeas;

        % Do meas update niter times
        for k = (thisint(end)+1):iint(ispan(i)), 
            
            if(upvec == 1)
                
                if ischmidt == 1
                    [Xhat{j}(:,k),Phat{j}(:,:,k),eflag{j}(isel,k),y{j}(isel,k),Pdy{j}(isel,isel,k)] = kalmup(datfun.est,...
                        tspan(i),Xhat{j}(:,k-1),Phat{j}(:,:,k-1),Y{j}(:,i),...
                        options.est,eopts.eflag,eopts.eratio,datarg.est,isel,S(:,:,i),C(:,:,i));  %#ok<PFBNS>
                else
                    [Xhat{j}(:,k),Phat{j}(:,:,k),eflag{j}(isel,k),y{j}(isel,k),Pdy{j}(isel,isel,k)] = kalmup(datfun.est,...
                        tspan(i),Xhat{j}(:,k-1),Phat{j}(:,:,k-1),Y{j}(:,i),...
                        options.est,eopts.eflag,eopts.eratio,datarg.est,isel);
                end

            else

                Xhat_tmp = Xhat{j}(:,k-1);

                Phat_tmp = Phat{j}(:,:,k-1);

                % This assumes that there are always the same number of measurements for
                % all cases for all time.
                for bb=1:nmeas

                    if ischmidt == 1
                        [Xhat_tmp,Phat_tmp,eflag{j}(bb,k),y{j}(bb,k),Pdy{j}(bb,bb,k)] = kalmup(datfun.est,...
                            tspan(i),Xhat_tmp,Phat_tmp,Y{j}(:,i),...
                            options.est,eopts.eflag,eopts.eratio,datarg.est,bb,S(:,:,i),C(:,:,i)); 
                    else
                        [Xhat_tmp,Phat_tmp,eflag{j}(bb,k),y{j}(bb,k),Pdy{j}(bb,bb,k)] = kalmup(datfun.est,...
                            tspan(i),Xhat_tmp,Phat_tmp,Y{j}(:,i),...
                            options.est,eopts.eflag,eopts.eratio,datarg.est,bb); 
                    end

                end

                Xhat{j}(:,k) = Xhat_tmp;

                Phat{j}(:,:,k) = Phat_tmp;

            end

        end

    end

end


%% Estimation Error Ensemble
% Generate the time series of estimation errors for each
% case.  Use estval to plot these data if no output arguments are supplied.

P = scrunch(P);
for j = ncases:-1:1,
    t{j} = titer;
    Phat{j} = scrunch(Phat{j}); % Need to look at solve for only
    for i = lenti:-1:1,
        % This misses any update iterations
        if ischmidt == 1
            e{j}(:,iint(i)) = Xhat{j}(:,iint(i)) - X{j}(:,i); 
        else
            e{j}(:,iint(i)) = Xhat{j}(:,iint(i)) - S(:,:,iint(i))*X{j}(:,i); 
        end
        % Fill in iterations if required
        if i == 1,
            thisint = 1;
        else
            thisint = iint(i-1)+1:iint(i)-1;
        end
        for k = thisint,
            if ischmidt == 1
                e{j}(:,k) = Xhat{j}(:,k) - X{j}(:,i); 
            else
                e{j}(:,k) = Xhat{j}(:,k) - S(:,:,k)*X{j}(:,i); 
            end
        end
    end
end

if demomode,
    estval(t,e,Phat,P,gcf)
    disp('You are in the workspace of ESTSEQ; type ''return'' to exit.')
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
    varargout{12} = Sig_sa;
end
if(nargout >= 13)
    varargout{13} = eflag;
end
if nargout >= 14,
    varargout{14} = Pdy;
end
if nargout >= 15,
    varargout{15} = Pdyt;
end
if nargout >= 16,
    varargout{16} = Pm;
    varargout{17} = Phatm;
end
if nargout >= 18,
    restartRecord.Pao = Pa(:,:,end);
    restartRecord.Pvo = Pv(:,:,end);
    restartRecord.Pwo = Pw(:,:,end);
    restartRecord.Pmo = Pm(:,:,end);
    restartRecord.Phatao = Phata(:,:,end);
    restartRecord.Phatvo = Phatv(:,:,end);
    restartRecord.Phatwo = Phatw(:,:,end);
    restartRecord.Phatmo = Phatm(:,:,end);
    restartRecord.Xrefo = Xref(:,end);
    restartRecord.Xsrefo = Xsref(:,end);
    for i = ncases:-1:1
        restartRecord.Xo(:,i) = X{i}(:,end);
        restartRecord.Xhato(:,i) = Xhat{i}(:,end);
        restartRecord.Phato(:,:,i) = unscrunch(Phat{i}(:,end));
    end
    restartRecord.Sig_ao = Sig_a(:,:,end);
    restartRecord.dynfun = dynfun;
    restartRecord.datfun = datfun;
    restartRecord.dynarg = dynarg;
    restartRecord.datarg = datarg;
    restartRecord.options = options;
    restartRecord.S = S(:,:,1);
    restartRecord.C = C(:,:,1);
    varargout{18} = restartRecord;
end
if nargout >= 19,
    varargout{19} = S;
    varargout{20} = C;
end

end % function

% ESTSEQ helper functions
function y = refine(u,refine)
y = [reshape([u(1:end-1);repmat(u(1:end-1),refine,1)+...
    cumsum(repmat(diff(u)/(refine+1),refine,1),1)],[],1);u(end)]';
end
