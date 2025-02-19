close all; clear all;

%% Code
Data = ['MATLAB is paradigm numerical computing'];

Datalen = length(Data);
Hidebitlen = Datalen * 8 + 8;

load JpegCoeff.mat;
load hall.mat

hwlen = size(hall_gray);
newhwlen = ceil(hwlen/8)*8;
newimg = zeros(newhwlen);

if(newhwlen(1)*newhwlen(2)/64 < Hidebitlen)
    error 'Image not big enough!';
end

newimg(1:hwlen(1),1:hwlen(2)) = hall_gray;
if(hwlen(1) < newhwlen(1))
    newimg(hwlen(1)+1:newhwlen(1),:) = hall_gray(hwlen(1),:);  
end
if(hwlen(2) < newhwlen(2))
    newimg(:,hwlen(2)+1:newhwlen(2)) = hall_gray(:,hwlen(2));
end

coef = zeros(64,newhwlen(1)*newhwlen(2)/64);
Datalenbit = bitget(Datalen,8:-1:1);
Datalenbit(Datalenbit==0) = -1;
Data = uint8(Data);

k = 1; l = 0;
for i = 1:newhwlen(1)/8
    for j = 1:newhwlen(2)/8
        c = dct2(newimg(8*i-7:8*i,8*j-7:8*j)-128);
        c = round(c ./ QTAB);
        order = c(zigzag(8));
        pos = find(order~=0);
        if(k <= Datalen)
            if(i == 1 && j <= 8)
                if(pos(length(pos))==64)
                    order(64) = Datalenbit(j);
                else
                    order(pos(length(pos))+1) = Datalenbit(j);
                end
                k = 1;
            else
                if(k > Datalen)
                    break;
                end
                temp = bitget(Data(k),8:-1:1);
                temp = double(temp);
                temp(temp==0) = -1;
                if(pos(length(pos))==64)
                    order(64) = temp(l+1);
                else
                    order(pos(length(pos))+1) = temp(l+1);
                end
                l = l + 1;
                if(~mod(l,8))
                    k = k + 1;
                    l = 0;
                end
            end
        end
        coef(:,(i-1)*newhwlen(2)/8+j) = order;
    end
end

% DC coef

DC = coef(1,:);
% DC = [10 8 60];
Diff = zeros(size(DC));
Diff(1) = DC(1);
for i = 2:length(Diff)
    Diff(i) = DC(i-1) - DC(i);
end
Dc_ceof = [];
Category_DC = ceil(log2(abs(Diff)+1));
for i = 1:length(Category_DC)
    huff = DCTAB(Category_DC(i)+1, 2:1+DCTAB(Category_DC(i)+1,1));
    dc = Diff(i);
    if(dc==0)
        Dc_ceof = [Dc_ceof huff];
    else
        amp = dec2bin(abs(dc)) - '0';
        if(dc<0)
            amp = 1 - amp;
        end
        Dc_ceof = [Dc_ceof huff amp];
    end
end

% AC coef
AC = coef(2:64,:);
% AC = [10 3 0 0 2 zeros(1,20) 1 zeros(1,37)]';
Ac_ceof = [];

for i = 1:size(AC,2);
    currentAC = AC(:,i);
    pos = find(currentAC~=0);
    if(~isempty(pos))
        previous = 1;
        for j = 1:length(pos)
            ac = currentAC(pos(j));
            run = pos(j)-previous;
            while(run>15)
                Ac_ceof = [Ac_ceof 1 1 1 1 1 1 1 1 0 0 1];
                run = run - 16;
            end
            amp = dec2bin(abs(ac)) - '0';
            if(ac<0)
                amp = 1 - amp;
            end
            Huff = ACTAB(run*10+length(amp),4:ACTAB(run*10+length(amp),3)+3);
            Ac_ceof = [Ac_ceof Huff amp];
            previous = pos(j) + 1;
        end
    end
    Ac_ceof = [Ac_ceof 1 0 1 0];
end
height = newhwlen(1);
width = newhwlen(2);

oef = zeros(64, height*width/64);
diff = zeros(1, height*width/64);
DC_Huff = DCTAB(:,2:size(DCTAB,2));
for i =1:size(DCTAB,1)
    DC_Huff(i, DCTAB(i,1)+1) = inf;
    DC_Huff(i, DCTAB(i,1)+2) = i;
end
AC_Huff = ACTAB(:,4:size(ACTAB,2));
for i =1:size(ACTAB,1)
    AC_Huff(i, ACTAB(i,3)+1) = inf;
    AC_Huff(i, ACTAB(i,3)+2) = i;
end
AC_Huff(size(AC_Huff,1)+1,1:11) = [1 1 1 1 1 1 1 1 0 0 1];
AC_Huff(size(AC_Huff,1),12) = inf;
AC_Huff(size(AC_Huff,1),13) = size(AC_Huff,1);
AC_Huff(size(AC_Huff,1)+1,1:4) = [1 0 1 0];
AC_Huff(size(AC_Huff,1),5) = inf;
AC_Huff(size(AC_Huff,1),6) = -inf;

%% Decode
% Process DC 
point = 1;
while(~isempty(Dc_ceof))
    temp_DC = DC_Huff;
    while(size(temp_DC,1)~=1)
        for i = size(temp_DC,1):-1:1
            if(temp_DC(i,1) ~= Dc_ceof(1))
                temp_DC(i,:) = [];
            end
        end
        temp_DC(:,1) = [];
        Dc_ceof(1) = [];
     end
    pos = find(temp_DC==inf);
    if(pos~=1)
        Dc_ceof(:,1:pos-1) = [];
    end
    
    if(temp_DC(pos+1)~=1)
        bin = Dc_ceof(1,1:(temp_DC(pos+1)-1));
        if(bin(1)==0)
            bin = ~bin;
            sign = false;
        else
            sign = true;
        end
        Dc_ceof(:,1:length(bin)) = [];
        bin = num2str(bin);
        dec = bin2dec(bin);
        if(sign)
            diff(1,point) = dec;
        else
            diff(1,point) = -dec;
        end
    else
        diff(1,point) = 0;
    end
    point = point + 1;
end

coef(1,1) = diff(1,1); 
for i = 2:length(diff)
    coef(1,i) = coef(1,i-1) - diff(1,i);
end

%% Process AC
point = 1;
rownum = 2;
while(~isempty(Ac_ceof))
    temp_AC = AC_Huff;
    while(size(temp_AC,1)~=1)
        for i = size(temp_AC,1):-1:1
            if(temp_AC(i,1) ~= Ac_ceof(1))
                temp_AC(i,:) = [];
            end
        end
        temp_AC(:,1) = [];
        Ac_ceof(1) = [];
    end
    pos = find(temp_AC==inf);
    if(pos~=1)
        Ac_ceof(:,1:pos-1) = [];
    end
    if(temp_AC(pos+1)==-inf)
        point = point + 1;
        rownum = 2;
    else
        numsize = mod(temp_AC(pos+1),10);
        numrun = floor(temp_AC(pos+1)/10);
        if(numsize == 0)
            numsize = 10;
            numrun = numrun - 1;
        end
        if(numrun == 16)
            rownum = rownum + numrun;
        else 
            bin = Ac_ceof(1,1:numsize);
            Ac_ceof(:,1:numsize) = [];
            if(bin(1)~=0)
                sign = true;
            else
                sign = false;
                bin = ~bin;
            end
            bin = num2str(bin);
            dec = bin2dec(bin);
            if(sign)
                coef(rownum+numrun,point) = dec;
            else
                coef(rownum+numrun,point) = -dec;
            end
            rownum = rownum + numrun + 1;
        end
    end
end
 
%% Anti-Qulified 
img = zeros(height, width);
numwidth = width/8;
j = 0;
decodeflag = true;
bitoflen = [];
bitofchrac = [];
GetData = [];
for i = 1:size(coef,2)
    if(decodeflag)
        temp = coef(:,i);
        pos = find(temp~=0);
        temp = temp(pos(length(pos)));
        if(temp == -1)
            temp = 0;
        end
        if(i <= 8)
            bitoflen = [bitoflen num2str(temp)];
            if(i == 8)
                bitlen = bin2dec(bitoflen);
            end
        else
            if(i > (bitlen + 1)*8)
                decodeflag = false;
            end
            bitofchrac = [bitofchrac num2str(temp)];
            if(~mod(i,8))
                GetData = [GetData char(bin2dec(bitofchrac))];
                bitofchrac = [];
            end
        end
    end
    currentblock(zigzag(8)) = coef(:,i);
    block88 = reshape(currentblock,8,8);
    block88 = round(block88 .* QTAB);
    imgblock = idct2(block88);
    tempw = mod(j,numwidth) + 1;
    temph = floor(j/numwidth) + 1;
    img(8*temph-7:8*temph,8*tempw-7:8*tempw) = imgblock;
    j = j + 1;
end
img = img + 128;
imshow(uint8(img));
imwrite(uint8(img), 'thirdhidden.jpg');

psnrvalue = psnr(uint8(img), hall_gray)
% save Dc_ceof Ac_ceof height width