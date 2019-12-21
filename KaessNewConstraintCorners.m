%{
 * Copyright (C) 2013-2020, The Regents of The University of Michigan.
 * All rights reserved.
 * This software was developed in the Biped Lab (https://www.biped.solutions/) 
 * under the direction of Jessy Grizzle, grizzle@umich.edu. This software may 
 * be available under alternative licensing terms; contact the address above.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * The views and conclusions contained in the software and documentation are those
 * of the authors and should not be interpreted as representing official policies,
 * either expressed or implied, of the Regents of The University of Michigan.
 * 
 * AUTHOR: Bruce JK Huang (bjhuang[at]umich.edu)
 * WEBSITE: https://www.brucerobot.com/
%}

function [cross_big_3d, edges]= KaessNewConstraintCorners(target_size, path, pc_mat, pc_iter)
    d=target_size*sqrt(2);

    pc = load(string(path) + string(pc_mat)); 
    pnts = pc.point_cloud; % [scan, point, [X, Y, X, I, R]]
    ransac_threshold = 0.02;

    [U,center,~,RE,~,~,LEupper,LElower,REupper,RElower,~,~,~] = LeftRightEdges_v02(pnts, d, pc_iter);
    [nL1,nL2,nL3]=size(LEupper);
    LEupperall=reshape(LEupper,nL1,nL2*nL3);
    I=find( (LEupperall(1,:)~= 10) & (LEupperall(2,:)~= 10) ); 
    edges.LU=U*[1 0; 0 1;0 0]*LEupperall(:,I) + center;
    LEupperal_new = LEupperall(:, I);
    [nR1,nR2,nR3]=size(RE);

    [nL1,nL2,nL3]=size(LElower);
    LElowerall=reshape(LElower,nL1,nL2*nL3);
    I=find( (LElowerall(1,:)~= 10) & (LElowerall(2,:)~= 10) ); 
    edges.LL=U*[1 0; 0 1;0 0]*LElowerall(:,I) + center;
    LElowerall_new = LElowerall(:, I);

    [nR1,nR2,nR3]=size(REupper);
    REupperall=reshape(REupper,nR1,nR2*nR3);
    I=find( (REupperall(1,:)~= 10) & (REupperall(2,:)~= 10) ); 
    edges.RU=U*[1 0; 0 1; 0 0]*REupperall(:,I) + center;
    REupperall_new = REupperall(:, I);

    [nR1,nR2,nR3]=size(RElower);
    RElowerall=reshape(RElower,nR1,nR2*nR3);
    I=find( (RElowerall(1,:)~= 10) & (RElowerall(2,:)~= 10) ); 
    edges.RL=U*[1 0; 0 1; 0 0]*RElowerall(:,I) + center;
    RElowerall_new = RElowerall(:, I);

    PhiEdges=[LEupperall(1,:)', 0*LEupperall(1,:)', 1+0*LEupperall(1,:)', 0*LEupperall(1,:)'; RElowerall(1,:)', 0*RElowerall(1,:)', 1+0*RElowerall(1,:)', 0*RElowerall(1,:)'; ...
        0*LElowerall(1,:)', LElowerall(1,:)', 0*LElowerall(1,:)', 1+0*LElowerall(1,:)'; 0*REupperall(1,:)', REupperall(1,:)', 0*REupperall(1,:)', 1+0*REupperall(1,:)'];

    YEdges=[LEupperall(2,:)-d/2, RElowerall(2,:)+d/2, LElowerall(2,:)+d/2, REupperall(2,:)-d/2]';

    mu1=-1;mu2=1;
    for k = 1:5
            beq=-1+mu1*mu2;
            Aeq=[mu2 mu1 0 0];

        if 0 % L2 <----
            if 0
                Beta=PhiEdges\YEdges;
                text='L2 no constraint';
            else
                Q=PhiEdges'*PhiEdges;
                f=-(YEdges')*PhiEdges;
                options = optimoptions('quadprog','Display','none');
                Beta = quadprog(Q,f,[],[],Aeq,beq,[],[],[], options);
                text='L2 with constraint';
            end
        elseif 1% L1
            [nr,nc]=size(PhiEdges);
            f=[zeros(1,nc), ones(1,nr)];
            Ain=[PhiEdges, -eye(nr); -PhiEdges -eye(nr)];
            bin=[YEdges;-YEdges];
            Aeq=[Aeq,zeros(1,nr)];
            options = optimoptions('linprog','Display','none');
            Beta=linprog(f,Ain,bin,Aeq,beq,[],[],[],options);
            Beta=Beta(1:nc);
            text='L1 with constraint';
        else % L-inf
            [nr,nc]=size(PhiEdges);
            f=[zeros(1,nc), 1];
            Ain=[PhiEdges, -ones(nr,1); -PhiEdges -ones(nr,1)];
            bin=[YEdges;-YEdges];
            Aeq=[Aeq,0];
            options = optimoptions('linprog','Display','none');
            Beta=linprog(f,Ain,bin,Aeq,beq,[],[],[],options);
            Beta=Beta(1:nc);
            text='L-inf with constraint';
        end

        mu1=Beta(1); mu2=Beta(2); b1=Beta(3);b2=Beta(4);

    end
    bLU=b1+d/2;
    bLL=b2-d/2;
    bRU=b2+d/2;
    bRL=b1-d/2;
%             disp(text)
%             disp(['mu1*mu2 = ']), disp(mu1*mu2)
%             Error_Edges=PhiEdges*Beta-YEdges;
%             RMSerror_Edges=sqrt((norm(Error_Edges)/length(YEdges)))


    %Let's plot the lines on the target or the edge points

    %RElowerTargetEdges=U*[1 0; 0 1; 0 0]*RElowerall + center;
%             edges.LU=U*[1 0; 0 1;0 0]*LEupperall(:,I) + center;
    edges.LU=U*[1 0; 0 1;0 0]*([1 0;mu1 0] *LEupperall + [0;bLU] ) + center;
    edges.LL=U*[1 0; 0 1;0 0]*([1 0;mu2 0] *LElowerall + [0;bLL] ) + center;
    edges.RU=U*[1 0; 0 1; 0 0]*([1 0;mu2 0] *REupperall +  [0;bRU])  + center;
    edges.RL=U*[1 0; 0 1; 0 0]*([1 0;mu1 0] *RElowerall +  [0;bRL] ) + center;

    LEupperall_new = ([1 0;mu1 0] *LEupperall + [0;bLU]);
    LElowerall_new = ([1 0;mu2 0] *LElowerall + [0;bLL]);
    REupperall_new = ([1 0;mu2 0] *REupperall + [0;bRU]);
    RElowerall_new = ([1 0;mu1 0] *RElowerall + [0;bRL]);

    modelInliers_TL = polyfit(LEupperall_new(1,:)', LEupperall_new(2,:)', 1);
    modelInliers_BL = polyfit(LElowerall_new(1,:)', LElowerall_new(2,:)', 1);

    modelInliers_TR = polyfit(REupperall_new(1,:)', REupperall_new(2,:)', 1);
    modelInliers_BR = polyfit(RElowerall_new(1,:)', RElowerall_new(2,:)', 1);

    cross_L=intersection(modelInliers_TL, modelInliers_BL);

    cross_R=intersection(modelInliers_TR, modelInliers_BR);

    cross_T=intersection(modelInliers_TL, modelInliers_TR);

    cross_B=intersection(modelInliers_BR, modelInliers_BL);

    cross_big_2d = [cross_T, cross_L, cross_R, cross_B];
%     figure(400)
%     hold on
%     plot(LEupperall_new(1, :), LEupperall_new(2, :))
%     plot(LElowerall_new(1, :), LElowerall_new(2, :))
%     plot(REupperall_new(1, :), REupperall_new(2, :))
%     plot(RElowerall_new(1, :), RElowerall_new(2, :))
%     title('2D edges')
%     scatter(cross_big_2d(1, :), cross_big_2d(2, :));
    cross_big_3d = U*[1 0; 0 1;0 0]*cross_big_2d + center;
    cross_big_3d = [cross_big_3d; ones(1,size(cross_big_3d,2))];
    cross_big_3d = sortrows(cross_big_3d', 3, 'descend')';

    
%     figure(500)
%     hold on
%     scatter3(cross_big_3d(1, :), cross_big_3d(2, :), cross_big_3d(3, :))
 end
