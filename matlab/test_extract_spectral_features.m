function test_extract_spectral_features()
% Synthetic numerical and equivariance fixtures.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

fs = 512;
t = (0:1023)'/fs;
x = [2*sin(2*pi*16*t), 3*sin(2*pi*96*t)];
bands = [12,20;80,112];
names = ["motor_low";"cortical_high"];
reference = ones(2,2);
N = 256;
H = 128;

base = extract_spectral_features( ...
    x,fs,N,H,bands,names,reference,0);

assert(all(abs(base.bandPowerMicrovoltsSquared(:,1,1)-2) < 1e-10));
assert(all(abs(base.bandPowerMicrovoltsSquared(:,2,2)-4.5) < 1e-10));

% Time-origin transformation changes timestamps, not feature values.
shifted = extract_spectral_features( ...
    x,fs,N,H,bands,names,reference,100);
assert(isequal(base.bandPowerMicrovoltsSquared, ...
    shifted.bandPowerMicrovoltsSquared));
assert(max(abs(shifted.windowStartSeconds ...
    -base.windowStartSeconds-100)) < 1e-12);

% Channel permutation must carry names and reference columns.
order = [2,1];
permuted = extract_spectral_features( ...
    x(:,order),fs,N,H,bands,names(order),reference(:,order),0);
expected = base.bandPowerMicrovoltsSquared(:,:,order);
assert(max(abs(permuted.bandPowerMicrovoltsSquared(:) ...
    -expected(:))) < 1e-10);

% Voltage gain 3 produces power gain 9.
gained = extract_spectral_features( ...
    3*x,fs,N,H,bands,names,reference,0);
expectedPower = 9*base.bandPowerMicrovoltsSquared;
assert(max(abs(gained.bandPowerMicrovoltsSquared(:) ...
    -expectedPower(:))) < 1e-9);

% Check log equivariance on features carrying substantial signal.
assert(all(abs(gained.logPowerRatio(:,1,1) ...
    -base.logPowerRatio(:,1,1)-log(9)) < 1e-10));

% A completed prefix cannot change earlier feature frames.
prefix = extract_spectral_features( ...
    x(1:512,:),fs,N,H,bands,names,reference,0);
frameCount = size(prefix.bandPowerMicrovoltsSquared,1);
expectedPrefix = base.bandPowerMicrovoltsSquared(1:frameCount,:,:);
assert(max(abs(prefix.bandPowerMicrovoltsSquared(:) ...
    -expectedPrefix(:))) < 1e-10);

% Reference power scales with voltage-unit conversion.
converted = extract_spectral_features( ...
    3*x,fs,N,H,bands,names,9*reference,0);
assert(all(abs(converted.logPowerRatio(:,2,2) ...
    -base.logPowerRatio(:,2,2)) < 1e-10));
end
