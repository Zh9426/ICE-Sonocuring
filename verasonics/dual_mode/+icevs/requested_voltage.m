function voltage=requested_voltage(settings)
%REQUESTED_VOLTAGE Empty hv preserves original startup semantics, not measured output.
% D00163 Rev.K section 12 p96: unspecified TPC.hv defaults to 1.6 V.
voltage=settings.voltage_v;
if isempty(voltage), voltage=1.6; end
end
