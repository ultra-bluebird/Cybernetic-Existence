function test_audit_spectral_frame_contract()
% Synthetic fixtures. No neural recordings or hardware operation.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

fs = 512;
N = 256;
t = (0:N-1)'/fs;
x = [2*sin(2*pi*16*t), 3*cos(2*pi*48*t)];

a = audit_spectral_frame_contract(x,fs,"raw",100);
assert(all(a.parsevalDiagnosticPassed));
assert(abs(a.enbwBins-1.5) < 1e-12);
assert(max(abs(a.integratedPSD-[2,4.5])) < 1e-10);

% Offset rejection is tested independently from gain behavior.
offset = audit_spectral_frame_contract(x+[5,-7],fs,"raw",100);
assert(max(abs(offset.oneSidedPSD(:)-a.oneSidedPSD(:))) < 1e-10);

gain = audit_spectral_frame_contract(3*x,fs,"raw",100);
assert(max(abs(gain.oneSidedPSD(:)-9*a.oneSidedPSD(:))) < 1e-9);

% The two normalization conventions have an explicit dimensional ratio.
expected = a.oneSidedPSD*a.enbwHz;
assert(max(abs(a.coherentNormalizedSpectrum(:)-expected(:))) < 1e-12);

% Weighted centering makes the tapered processed frame sum approximately zero.
weighted = audit_spectral_frame_contract(x+4,fs,"weighted",100);
assert(max(abs(weighted.processedFrameDFT(1,:))) < 1e-10);

% Supplied rail diagnostics detect these exact endpoint observations.
rails = audit_spectral_frame_contract([100;-100;0;0],fs,"none",100);
assert(rails.atOrBeyondDeclaredRailCount == 2);

% Reference changes need not change already average-referenced input.
averageReferenced = x-mean(x,2);
againReferenced = averageReferenced-mean(averageReferenced,2);
assert(max(abs(againReferenced(:)-averageReferenced(:))) < 1e-12);
end
