function w = PlateBendingMorley(node,elem,pde,bdStruct)

para = pde.para; f = pde.f; D = para.D; nu = para.nu;
% -------- Sparse assembling indices -----------
N = size(node,1); NT = size(elem,1); Ndof = 6;
auxT = auxstructure(node,elem);
elem2edge = auxT.elem2edge; edge = auxT.edge;
NE = size(edge,1);
elem2 = [elem, elem2edge+N];

nnz = NT*Ndof^2;
ii = zeros(nnz,1); jj = zeros(nnz,1);
id = 0;
for i = 1:Ndof
    for j = 1:Ndof
        ii(id+1:id+NT) = elem2(:,i);
        jj(id+1:id+NT) = elem2(:,j);
        id = id + NT;
    end
end

% -------------- parameters used in the computation --------------------
auxG = auxgeometry(node,elem);  area = auxG.area;
x1 = node(elem(:,1),1); y1 = node(elem(:,1),2);
x2 = node(elem(:,2),1); y2 = node(elem(:,2),2);
x3 = node(elem(:,3),1); y3 = node(elem(:,3),2);
% xi, eta
xi = [x2-x3, x3-x1, x1-x2]; eta = [y2-y3, y3-y1, y1-y2];
% sij
sb = zeros(NT,3,3);
for i = 1:3
    for j = 1:3
        sb(:,i,j) = -xi(:,i).*xi(:,j) - eta(:,i).*eta(:,j);
    end
end
% elementwise edge length
z1 = node(edge(:,1),:); z2 = node(edge(:,2),:);
he = sqrt(sum((z2-z1).^2,2)); L = he(elem2edge);
% elementwise sign of basis functions
sgnelem = sign([elem(:,3)-elem(:,2), elem(:,1)-elem(:,3), elem(:,2)-elem(:,1)]);
bdIndex = bdStruct.bdIndex;
E = false(NE,1); E(bdIndex) = 1; sgnbd = E(elem2edge);
sgnelem(sgnbd) = 1;
sgnbase = ones(NT,Ndof); sgnbase(:,4:6) = sgnelem;
% coefficients in the basis functions
ind = [1 2 3; 2 3 1; 3 1 2];  % rotation index
it = ind(:,1); jt = ind(:,2); kt = ind(:,3);
c0 = zeros(NT,3); c1 = c0; c2 = c0;
for i = 1:3
    j = ind(i,2); k = ind(i,3);
    c0(:,i) = 1./(2*area.^2);
    c1(:,i) = sb(:,i,j)./L(:,j).^2;
    c2(:,i) = sb(:,k,i)./L(:,k).^2;
end
c3 = c1+c2;
% Gauss quadrature rule
[lambda,weight] = quadpts(2);
nI = length(weight);

% -------------- Second derivatives of basis functions --------------------
b11 = zeros(NT,6); b22 = b11; b12 = b11; % [phi_i, i=1:6]
% i = 1,2,3
b11(:,it) = c0.* (eta(:,it).^2 - c1.*eta(:,jt).^2 - c2.*eta(:,kt).^2);
b22(:,it) = c0.* (xi(:,it).^2 - c1.*xi(:,jt).^2 - c2.*xi(:,kt).^2);
b12(:,it) = -c0.* (xi(:,it).*eta(:,it) - c1.*xi(:,jt).*eta(:,jt) - c2.*xi(:,kt).*eta(:,kt));
% i = 4,5,6
ci = 1./(repmat(area,1,3).*L(:,it));
b11(:,3+it) = ci.*eta(:,it).^2;
b22(:,3+it) = ci.*xi(:,it).^2;
b12(:,3+it) = -ci.*xi(:,it).*eta(:,it);

% ----------- First stiffness matrix and sign matrix -----------
K = zeros(NT,Ndof^2);  sgnK = zeros(NT,Ndof^2);
s = 1;
for i = 1:Ndof
    for j = 1:Ndof
        K(:,s) = b11(:,i).*b11(:,j) + b22(:,i).*b22(:,j) ...
            + nu*(b11(:,i).*b22(:,j) + b22(:,i).*b11(:,j)) ...
            + 2*(1-nu)*b12(:,i).*b12(:,j);
        sgnK(:,s) = sgnbase(:,i).*sgnbase(:,j);
        s = s+1;
    end
end
K = D*repmat(area,1,Ndof^2).*K;

% ------------- Second stiffness matrix and load vector ------------
G = zeros(NT,Ndof^2); F = zeros(NT,Ndof);
if isnumeric(para.c), cf = @(xy) para.c+0*xy(:,1); end
for p = 1:nI
    % quadrature points in the x-y coordinate
    pxy = lambda(p,1)*node(elem(:,1),:) ...
        + lambda(p,2)*node(elem(:,2),:) ...
        + lambda(p,3)*node(elem(:,3),:);
    % basis functions at the p-th quadrture point
    base = zeros(NT,Ndof);
    % i = 1,2,3    
    base(:,it) = repmat(lambda(p,it).^2,NT,1) ...
               + c3.*repmat(lambda(p,jt).*lambda(p,kt),NT,1) ...
               + c2.*repmat(lambda(p,kt).*lambda(p,it),NT,1) ...
               + c1.*repmat(lambda(p,it).*lambda(p,jt),NT,1);
    % i = 4,5,6
    ci = 2*repmat(area,1,3)./L(:,it);
    base(:,3+it) = ci.*repmat(lambda(p,it).*(lambda(p,it)-1),NT,1);    
    % Second stiffness matrix
    s = 1;
    for i = 1:Ndof
        for j = 1:Ndof
            gs = cf(pxy).*base(:,i).*base(:,j);
            G(:,s) = G(:,s) + weight(p)*gs;
            s = s+1;
        end
    end
    % load vector
    F = F + weight(p)*repmat(f(pxy),1,Ndof).*base;
end
G = repmat(area,1,Ndof^2).*G; 
F = repmat(area,1,Ndof).*F;
sgnF = ones(NT,Ndof); sgnF(:,4:6) = sgnelem; % sign vector

% ------------- Assemble stiffness matrix and load vector ------------
kk = sparse(ii,jj,(K(:)+G(:)).*sgnK(:),N+NE,N+NE);
ff = accumarray(elem2(:), F(:).*sgnF(:), [N+NE 1]);

% ------------ Dirichlet boundary conditions ----------------
eD = bdStruct.eD; elemD = bdStruct.elemD;
g_D = pde.g_D;  Dw = pde.Dw;

id = [eD; bdIndex+N];
isBdNode = false(N+NE,1); isBdNode(id) = true;
bdDof = isBdNode; freeDof = ~isBdNode;

pD = node(eD,:); wD = g_D(pD);
z1 = node(elemD(:,1),:); z2 = node(elemD(:,2),:); zc = (z1+z2)./2;
e = z1-z2;  % e = z2-z1
ne = [-e(:,2),e(:,1)];  ne = ne./repmat(he(bdIndex),1,2);
wnD = sum(Dw(zc).*ne,2);
w = zeros(N+NE,1); w(bdDof) = [wD;wnD];
ff = ff - kk*w;

% ------------------ Solver -------------------
w(freeDof) = kk(freeDof,freeDof)\ff(freeDof);
w = w(1:N);