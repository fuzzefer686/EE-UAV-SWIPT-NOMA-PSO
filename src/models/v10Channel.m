function h = v10Channel(uavXYZ, nodesXYZ, fading, radio)
%V10CHANNEL V9 path-loss/Rician equations with radio constants from config.
    horizontal=hypot(uavXYZ(1)-nodesXYZ(:,1),uavXYZ(2)-nodesXYZ(:,2));
    vertical=abs(uavXYZ(3)-nodesXYZ(:,3));
    distance=hypot(horizontal,vertical);
    if any(distance<=0) || any(~isfinite(distance))
        error('v10Channel:Distance','UAV and communication nodes must have finite positive distance.');
    end
    angle=atan2(vertical,max(horizontal,eps));
    gain=radio.referenceGain.*distance.^(-radio.pathLossExponent);
    K=radio.A1.*exp(radio.A2.*angle);
    ric=sqrt(K./(1+K))*radio.losAmplitude+sqrt(1./(1+K)).*fading(:);
    h=(sqrt(gain).*ric).';
end
