function [Pro,Res] = transferoperator(elem,J)
%transferoperator2 returns the prolongation matrices and restriction
% matrices of meshes obtained by using uniformrefine2.m
% node, elem: the final mesh
% J: level number
%
% Copyright (C) Terence Yu.

% 3                             % 3
% | \                           % | \
% 5- 4                          % |  \
% |\ |\                         % |   \
% 1- 6- 2                       % 1- - 2
%
% elem: [1 6 5],    [6 2 4],     [5 4 3],        [4 5 6]
%       1:NT,       NT+1:2*NT,   2*NT+1:3*NT,    3*NT+1:4*NT

Pro = cell(J-1,1); Res = cell(J-1,1);

for j = J:-1:2
    
    %% HB in the level J-1
    N = max(elem(:));  NT = size(elem,1);
    NT = NT/4; % number of coarse elements
    t1 = 1:NT; t2 = t1+NT; t3 = t2+NT; t4 = t3+NT;
    HB = zeros(3*NT,3);  % elementwise HB
    HB(:,1) = reshape(elem(t4,:), [], 1);
    elem = [elem(t1,1), elem(t2,2), elem(t3,3)]; % coarse mesh
    HB(:, 2) = reshape(elem(:,[2,3,1]), [], 1);
    HB(:, 3) = reshape(elem(:,[3,1,2]), [], 1);
    [~,idx] = unique(HB(:,1));
    HB = HB(idx,:);   
    %% Transfer matrices in the level J-1
    Coarse2Fine = unique(elem(:)); CoarseId = Coarse2Fine;
    nCoarse = length(CoarseId);  nFine = N;  nf = size(HB,1);
    ii = [Coarse2Fine; HB(:,1); HB(:,1)];
    jj = [CoarseId; HB(:,2); HB(:,3)];
    ss = [ones(nCoarse,1); 0.5*ones(nf,1); 0.5*ones(nf,1)];
    Pro{j-1} = sparse(ii,jj,ss,nFine,nCoarse);
    Res{j-1} = Pro{j-1}';
    
end

