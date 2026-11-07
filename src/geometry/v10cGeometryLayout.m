function layout = v10cGeometryLayout(sim, optimizeBS)
%V10CGEOMETRYLAYOUT Geometry only; future resource solvers own alpha and times.
    if nargin<2, optimizeBS=true; end
    n=sim.numSteps-2;
    layout.x=1:n; layout.y=n+(1:n);
    layout.xBS=[]; layout.yBS=[]; layout.dimension=2*n;
    if optimizeBS
        layout.xBS=2*n+(1:sim.noBS);
        layout.yBS=2*n+sim.noBS+(1:sim.noBS);
        layout.dimension=2*n+2*sim.noBS;
    end
end
