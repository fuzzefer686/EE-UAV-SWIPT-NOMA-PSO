function out = v10cMotionEnergy(distance, flight, motion)
%V10CMOTIONENERGY Inherited steady model or explicitly gated QS extension.
% Experimental energy is NOT Dai's published PECM and has no calibrated
% acceleration, attitude-transition, yaw, circuit or motor-efficiency model.
    validateattributes(distance,{'numeric'},{'real','finite','vector','nonnegative'});
    distance=distance(:); count=numel(distance); vc=flight.cruiseSpeed;
    out.time=zeros(count,1); out.energy=zeros(count,1);
    out.peakSpeed=zeros(count,1); out.cruiseTime=zeros(count,1);
    out.mode=motion.mode;
    switch motion.mode
        case 'steady-drones'
            power=dronePropulsionPower(vc,flight);
            out.time=distance/vc; out.energy=power*out.time;
            out.peakSpeed(distance>0)=vc; out.cruiseTime=out.time;
            out.modelStatus='inherited-steady-horizontal-model';
        case 'rest-to-rest-experimental'
            if ~motion.allowExperimental
                error('V10C:ExperimentalOptIn','Experimental motion requires explicit opt-in.');
            end
            a=motion.acceleration;
            validateattributes(a,{'numeric'},{'real','finite','scalar','positive'});
            for t=1:count
                if distance(t)==0, continue; end
                peak=min(vc,sqrt(a*distance(t)));
                cruise=max(0,distance(t)-peak^2/a)/peak;
                out.peakSpeed(t)=peak; out.cruiseTime(t)=cruise;
                out.time(t)=2*peak/a+cruise;
                ramp=integral(@(v) quasiSteady(v,a,flight) ...
                    +quasiSteady(v,-a,flight),0,peak, ...
                    'AbsTol',motion.quadratureTolerance, ...
                    'RelTol',motion.quadratureTolerance)/a;
                out.energy(t)=ramp+dronePropulsionPower(peak,flight)*cruise;
            end
            out.modelStatus='experimental-quasi-steady-thrust-not-validated';
        otherwise
            error('V10C:MotionMode','Unknown movement energy model.');
    end
end

function power = quasiSteady(v,a,f)
% Research hypothesis: insert force-balance thrust into steady rotor power.
    n=f.numRotors; rho=f.airDensity; A=f.rotorArea;
    cT=f.thrustCoefficient; cs=f.rotorSolidity;
    drag=0.5*rho*f.flatPlateArea.*v.^2;
    thrust=hypot(f.mass*f.gravity,f.mass*a+drag)/n;
    profile=n*f.bladeDrag/8.*(thrust/(cT*rho*A)+3*v.^2) ...
        .*sqrt(thrust*rho*cs^2*A/cT);
    u=thrust/(2*rho*A); w=v.^2/2;
    induced=n*(1+f.inducedCorrection).*thrust ...
        .*sqrt(u.^2./(hypot(u,w)+w));
    parasite=n*0.5*f.fuselageDragRatio*rho*cs*A.*v.^3;
    power=profile+induced+parasite;
end
