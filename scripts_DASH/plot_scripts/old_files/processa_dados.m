dados=load('psnr_1.txt');
d2=load('psnr_2.txt');

figure(1)
plot(dados(:,1),dados(:,2),'k',d2(:,1),d2(:,2))
grid
% %axis([1 6,2 4])
% xlabel('Frequência (GHz)')
% ylabel('|S_{11}| (dB)')
% legend('Simulado','Medido')

figure(2)
plot(dados(:,1),dados(:,6),d2(:,1),d2(:,6))
grid
% xlabel('Frequência (GHz)')
% ylabel('Ganho (dBi)')
% legend('Simulado','Medido')

