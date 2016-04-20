function main()
    // Plus le masque est grand, moins le détecteur est sensible au bruit
    masque_gaussien = [2,4,2;
    4,9,4;
    2,4,2];

    // disp("MASQUE 3*3 : ")
    // disp(masque_gaussien);

    //image = ones(10,10); // Cas très simple pour tester 
    //image = chargerImage('\\Mac\Home\Desktop\TraitementImage\LENNA.jpg', 0);
    image = chargerImage('\\Mac\Home\Desktop\TraitementImage\logo2.png', 1);
    // image = chargerImage('\\Mac\Home\Desktop\TraitementImage\little.jpg', 0);

    image_filtre = appliquerFiltre(image, masque_gaussien); 
    //afficherImage(image_filtre);

    [Es,E0,non_maximums] = supprimerNonMaximums(image_filtre);
    afficherImage(cat(2,Es,E0,non_maximums));
    //afficherImage(image_filtre - non_maximums);

    // ======================================================
    // VERIFICATIONS AVEC LES FONCTIONS INCLUSENT DANS SCILAB
    // ======================================================

    // scilab_image_contours = edge(scilab_image_filtre, 'canny'); // Détection des contours avec le filtre de Canny
    // assert_checktrue(isequal(image_contours,scilab_image_contours)); // Validation du filtre de Canny

    // VALIDATION PARTIELLES
    // ---------------------

    // masque_gaussien = normaliserMasque(masque_gaussien); // imfilter s'attends à un masque déjà normalisé
    // scilab_image_filtre = imfilter(image, masque_gaussien); // La fonction 'imfilter' permet de faire une convolution d'une image par un filtre.
    // disp(image_filtre - scilab_image_filtre); // Il y a des effets de bords sur les contours. On peut cependant vérifier que l'écart entre les deux images tends vers 0 sur la pluspart des pixels.

    // AFFICHAGE
    // ---------

    // render = [image image_filtre scilab_image_filtre]; // Pour pouvoir afficher plusieurs images en même temps
    // afficherImage(image_filtre);

endfunction

// =============================
// ALGORITHME DU FILTRE DE CANNY
// =============================

// Un seuil trop bas peut conduire à la détection de faux positifs. Inversement, un seuil trop haut peut empêcher la détection de contours peu marqués mais représentant de l'information utile
function image_contours = filtreCanny(image, masque_gaussien, seuil_haut, seuil_bas)
    // Le masque est symétrique. Il n'y a pas besoin de retourner le masque dans les 2D lors de la convolution.
    assert_checktrue(isequal(masque_gaussien, masque_gaussien.')); // Une matrice est symétrique si elle est égale à sa transposée.  


    // Chaine sequentielle de 4 etape
    // Boucle 1 : filtrage gaussien
    // Boucle 2 : gradients en x et y
    // Boucle 3 : supression des non maximums
    // Boucle 4 : seuillage hysteresis
    // TODO: bonne séquence d'appels des fonctions ci dessous (voir sujet TP)
endfunction

// Il n'existe pas actuellement de méthode générique pour déterminer des seuils produisant des résultats satisfaisants sur tous les types d'images.
function image_contours = filtreCannySemiAuto(image, masque_gaussien)
    // TODO: Etre dépendant que d'un seul seuil et non 2. seuil_bas = 0.5 * seuil_haut et il faut calculer le seuil haut (voir sujet TP)
    // seuil_haut = ...
    // seuil_bas = seuil_haut / 2;
    // filtreCanny(image, masque_gaussien, seuil_haut, seuil_bas);
endfunction

// ========================
// 1) REHAUSSEMENT DE CANNY
// ========================


// On divise par la somme des pixels du masque pour ne pas modifier la valeur moyenne de l'image
function masque = normaliserMasque(masque)
    // (re)-definition du masque en divisant chaque valeur par la somme des valeurs du masque
    total_pixels = sum(masque);
    if total_pixels == 0 then
        total_pixels = 1;
    end
    masque = (1 / total_pixels). * masque; 
endfunction

// La première étape est de réduire le bruit de l'image originale avant d'en détecter les contours
// Ceci permet d'éliminer les pixels isolés qui pourraient donner une forte intensité lors du calcul du gradient et donc de faux positifs
function image_filtre = appliquerFiltre(image,masque)
    masque = normaliserMasque(masque);
    image = agrandirImage(image);
    demi_taille_masque_x = floor(size(masque, 1) / 2);
    demi_taille_masque_y = floor(size(masque, 2) / 2);
    [nb_lignes_image, nb_colonnes_image] = size(image); 
    [taille_x_masque, taille_y_masque] = size(masque); 

    // Faire le dessin pour bien comprendre les valeures des index. On itère sur les pixels de l'image et non sur le cadre augmenté.
    for i_image = 1 + demi_taille_masque_x : nb_lignes_image - demi_taille_masque_x
        for j_image = 1 + demi_taille_masque_y : nb_colonnes_image - demi_taille_masque_y
            somme = 0; // Faire la somme pour chaque pixel de l'image
            x2 = i_image - (demi_taille_masque_x + 1);
            y2 = j_image - (demi_taille_masque_y + 1);

            for x_masque = 1 : taille_x_masque 
                for y_masque = 1 : taille_y_masque
                    pixel_image = image(x2 + x_masque  , y2 + y_masque);
                    pixel_masque = masque(x_masque,y_masque);
                    somme = somme + (pixel_masque * pixel_image);
                end
            end
            image_filtre(i_image - demi_taille_masque_x, j_image - demi_taille_masque_y) = somme; // Le résultat est de la taille de l'image initiale, avant aggrandissement, création à la volée.
        end
    end
endfunction

// Calcul pour chaque pixel de l'image, la norme du gradient et l'angle de la normale au gradient.
// Un filtre gaussien doit déjà avoir été appliqué à l'image d'entrée.
function [norme_gradient, angle_normale_gradient] = calculGradient(image)
    masque_convolution_x = [1,0,-1]; // Donné dans le cours
    masque_convolution_y = [1;0;-1]; // Donné dans le cours

    matrice_gradient_x = appliquerFiltre(image, masque_convolution_x); 
    matrice_gradient_y = appliquerFiltre(image, masque_convolution_y); 

    [nb_lignes_image, nb_colonnes_image] = size(image); 

    norme_gradient = zeros(nb_lignes_image, nb_colonnes_image); // es
    angle_normale_gradient = zeros(nb_lignes_image, nb_colonnes_image); // eo

    for x = 1 : nb_lignes_image
        for y = 1 : nb_colonnes_image
            Jx = matrice_gradient_x(x,y);
            Jy = matrice_gradient_y(x,y);
            norme_gradient(x,y) = sqrt(Jx**2 + Jy**2); 
            angle_normale_gradient(x,y) = atan(-Jy, Jx); // Résultat en radians, à convertir en degrés // TODO: valeures
            angle_normale_gradient(x,y) = approxAngleNormaleGradient(angle_normale_gradient(x,y));
        end
    end
endfunction

function degre = radianEnDegre(radian)
    degre = 180 * radian / %pi;
endfunction

function valeur_degre = approxAngleNormaleGradient(valeur_radian)
    valeur_degre = radianEnDegre(valeur_radian);
    if (valeur_degre < 0) then
        valeur_degre = valeur_degre + 180; // Se ramener au demi cercle trigo supérieur
    end
    // On veut maintenant n'avoir que des valeurs 0, 45, 90, 135 ou 180°
    seuil_min_45 = 45 / 2;
    seuil_min_90 = (90 + 45) / 2;
    seuil_min_135 = (135 + 90) / 2;
    seuil_max_135 = (180 + 135) / 2;

    // On sait que valeur_degre > 0
    if valeur_degre >= seuil_min_45 & valeur_degre < seuil_min_90 then
        valeur_degre = 45;
    elseif valeur_degre >= seuil_min_90 & valeur_degre < seuil_min_135 then
        valeur_degre = 90;
    elseif valeur_degre >= seuil_min_135 & valeur_degre < seuil_max_135  then
        valeur_degre = 135;
    else
        valeur_degre = 0;
    end
    // TODO: vérification que valeur_degre est forcément une des valeur voulue
endfunction

// Pour pouvoir appliquer un masque sur l'image, on doit pouvoir se placer sur des pixels se trouvant à côté de notre image de départ.
function image_aggrandie = agrandirImage(image, masque)
    [nb_lignes_masque, nb_colonnes_masque] = size(masque);
    [nb_lignes_image, nb_colonnes_image] = size(image);

    demi_taille_masque_x = floor(nb_lignes_masque / 2); // Permet de savoir combien de pixels il faut agrandir le cadre de notre image originale. Lignes ou colonnes peu importe car masque carré. Floor = arrondi vers le bas.
    demi_taille_masque_y = floor(nb_colonnes_masque / 2); // Permet de savoir combien de pixels il faut agrandir le cadre de notre image originale. Lignes ou colonnes peu importe car masque carré. Floor = arrondi vers le bas.

    // Création d'une nouvelle matrice (vide) de taille aggrandie.
    nb_lignes_aggrandie = nb_lignes_image + 2 * demi_taille_masque_x; // On multiplie par 2 car on souhaite agrandir sur les quatres extrémitées
    nb_colonnes_aggrandie = nb_colonnes_image + 2 * demi_taille_masque_y;
    image_aggrandie = zeros(nb_lignes_aggrandie, nb_colonnes_aggrandie);

    // On replace maintenant notre image originale dans la nouvelle matrice en se décallant correctement par rapport à ce qu'on a aggrandi. On veux l'image originale au centre.
    for x = demi_taille_masque_x :(nb_lignes_aggrandie - demi_taille_masque_x)
        for y = demi_taille_masque_y :(nb_colonnes_aggrandie - demi_taille_masque_y)
            // On reprends les pixels de l'image initiale depuis le début
            x_image_origin = x - demi_taille_masque_x;
            y_image_origin = y - demi_taille_masque_y;
            if (x_image_origin > 0 & y_image_origin > 0) then // Les indices scilab commencent à 1 et non à 0
                image_aggrandie(x,y) = image(x_image_origin,y_image_origin);
            end
        end
    end
endfunction

// ==============================
// 2) SUPRESSION DES NON-MAXIMUMS
// ==============================

// Une forte intensité ne suffit pas à décider si un point correspond à un contour ou non. Il faut que ces fortes intensités correspondent à des maximas locaux.
function [es,eo,non_maximums] = supprimerNonMaximums(image)
    [nb_lignes_image, nb_colonnes_image] = size(image);
    [es,eo] = calculGradient(image);
    
    non_maximums = zeros(nb_lignes_image,nb_colonnes_image);
    
    for x = 1 : nb_lignes_image
        for y = 1 : nb_colonnes_image
            angle = eo(x,y);
            [voisin1, voisin2] = recupererVoisins(angle,es,x,y);
            if es(x,y) < voisin1 | es(x,y) < voisin2 then // Si plus grand qu'au moins un des deux voisins, on supprime
                non_maximums(x,y) = 0;
            else
                non_maximums(x,y) = es(x,y);
            end
        end       
    end
endfunction

function [voisin1, voisin2] = recupererVoisins(angle,es,x,y)
    select angle
    case 0 then
        voisin1 = recupererValeurVoisin(es, x , y - 1);
        voisin2 = recupererValeurVoisin(es, x , y + 1);
    case 45 then
        voisin1 = recupererValeurVoisin(es, x - 1, y + 1);
        voisin2 = recupererValeurVoisin(es, x + 1, y - 1);
    case 90 then
        voisin1 = recupererValeurVoisin(es, x - 1, y);
        voisin2 = recupererValeurVoisin(es, x + 1, y);
    case 135 then
        voisin1 = recupererValeurVoisin(es, x - 1, y - 1);
        voisin2 = recupererValeurVoisin(es, x + 1, y + 1);
    end
endfunction

function norme = recupererValeurVoisin(es,x,y)
    [nb_lignes, nb_colonnes] = size(es);
    if x>0 & x<=nb_lignes & y>0 & y<=nb_colonnes then // Si on tente d'accéder à un pixel en dehors de notre matrice, on renvoi 0
        norme = es(x,y);
    else
        norme = 0 ;
    end
endfunction

// ===========================
// 3) SEUILLAGE PAR HYSTERESIS
// ===========================

// Les contours donnés par les fortes valeurs du gradient sont souvent étalés, voire flous. Le seuillage à hystérésis permet de les affiner et de ne conserver que les contours les plus cohérents
function seuillageHysteresis(image, seuil_haut, seuil_bas)
    assert_checktrue(seuil_haut > seuil_bas);
    // TODO:
    
    il faut faire 2x2 boucles (un part puce du sujet)
    pour avoir la tagente à e0 il faut ajouter 90° (si e0+90 > 180 on fait -180)
endfunction


// =====================
// FONCTIONS UTILITAIRES
// =====================

function matrice_image = chargerImage(path,isRGB)
    // Dans tous les cas, nous voulons travailler sur une image en niveaux de gris (pas de couleurs)
    if isRGB == 0 then
        matrice_image = double(imread(path));
    else // Image d'origne en couleur
        matrice_image = double(rgb2gray(imread(path)));
    end
endfunction

function afficherImage(matrice_image)
    // Affiche la représentation d'une imge à partir de sa matrice dans l'utilitaire de scilab
    imshow(uint8(matrice_image));
endfunction

function image = ecrireImage(matrice_image, nom_fichier)
    // Sauvegarde l'image sur le système de fichier, à partir de l'emplacement courant
    image = imwrite(matrice_image, nom_fichier);
endfunction
main
