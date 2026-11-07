function writeV11AlphaStudySummary(fid, T, presets, variants, targets)
%WRITEV11ALPHASTUDYSUMMARY Stable singleton/empty/infeasible group reporting.
    fprintf(fid,'Full PSO rows; wallClockSeconds covers runV11 (all three algorithms).\n');
    fprintf(fid,'Swarm settings equal; total fitness/rate evaluations can differ.\n');
    fprintf(fid,'Mean +/- std across seeds, grouped by preset/variant/L.\n');
    for p=1:numel(presets)
        for v=1:numel(variants)
            for k=1:numel(targets)
                label=mat2str(targets{k}(:).',17);
                pick=strcmp(T.preset,presets{p}) & strcmp(T.variant,upper(variants{v})) & strcmp(T.LLabel,label);
                if ~any(pick), continue; end
                x=T.eeUAV(pick); feasible=T.feasible(pick);
                fprintf(fid,'%s V11%s L=%s n=%d feasible=%d | EE %.9g +/- %.9g bit/J\n', ...
                    presets{p},upper(variants{v}),label,numel(x),sum(feasible),mean(x),sampleStd(x));
                if any(feasible)
                    xf=x(feasible);
                    fprintf(fid,'  Feasible-only EE: %.9g +/- %.9g (n=%d)\n',mean(xf),sampleStd(xf),numel(xf));
                else
                    fprintf(fid,'  (no feasible run)\n');
                end
            end
        end
    end
end

function value = sampleStd(x)
    value=NaN;
    if numel(x)>1, value=std(x); end
end
