function main()
    // On prend un masque symétrique. Plus le masque est grand, moins le détecteur est sensible au bruit
    masque_gaussien = [2, 4, 5, 4, 2;
    4, 9, 12, 9, 4;
    5, 12, 15, 12, 5;
    4, 9, 12, 9, 4;
    2, 4, 5, 4, 2];

    assert_checktrue(isequal(masque_gaussien, masque_gaussien.')); // Une matrice est symétrique si elle est égale à sa transposée.  

    image = chargerImage('\\Mac\Home\Desktop\TraitementImage\BVOZEL\olympics.jpg', 1); // TODO: À remplacer par l'utilisateur

    // VERSION MANUELLE
    // ----------------
    contours = filtreCanny(image, masque_gaussien, 50, 10); // Version "manuelle" à deux seuils TODO: Les seuils sont dépendant de l'image dont on cherche les contours

    // VERSION SEMI-AUTOMATIQUE
    // ------------------------
    centile = 0.85; // Pourcentage pour le filtre semi-automatique. Faire varier en 0.70 et 0.95
    assert_checktrue(centile > 0);
    assert_checktrue(centile < 1);
    contours = filtreCannySemiAuto(image, masque_gaussien, centile); // Version semi-automatique

    // Affichage de l'image originale et des contours détectés par l'algorithme de Canny
    //render = cat(2, image, contours);
    afficherImage(contours);
endfunction

// =============================
// ALGORITHME DU FILTRE DE CANNY
// =============================

// Un seuil trop bas peut conduire à la détection de faux positifs. Inversement, un seuil trop haut peut empêcher la détection de contours peu marqués 
// Soucis : seuils difficiles à trouver et changent d'une image à l'autre ! Il faut y aller à taton pour chaque image pour avoir un bon rendu, c'est lourd et nécessite une intervention manuelle
function contours = filtreCanny(image, masque_gaussien, seuil_haut, seuil_bas)
    // Étape 1 : Appliquer un filtre gaussien pour réduction du bruit
    image_filtre = appliquerFiltre(image, masque_gaussien); 

    // Étape 2 : Calcul des gradients en x et y ainsi que l'angle de la normale
    [norme_gradient, angle_normale_gradient] = calculGradient(image_filtre);

    // Étape 3 : Supprimer les non-maximums
    non_maximums = supprimerNonMaximums(norme_gradient, angle_normale_gradient);

    // Étape 4 : Seuillage par hystérésis
    contours = seuillageHysteresis(non_maximums, angle_normale_gradient, seuil_haut, seuil_bas);
endfunction

// Il n'existe pas actuellement de méthode générique pour déterminer des seuils produisant des résultats satisfaisants sur tous les types d'images.
function contours = filtreCannySemiAuto(image, masque_gaussien, centile)
    // Étape 1 : Appliquer un filtre gaussien pour réduction du bruit (identique méthode 'manuelle')
    image_filtre = appliquerFiltre(image, masque_gaussien); 

    // Étape 2 : Calcul des gradients en x et y ainsi que l'angle de la normale (identique méthode 'manuelle')
    [norme_gradient, angle_normale_gradient] = calculGradient(image_filtre);

    // Étape 3 : Supprimer les non-maximums (identique méthode 'manuelle')
    non_maximums = supprimerNonMaximums(norme_gradient, angle_normale_gradient);

    // Étape 4 : détermination des seuils de manière semi-automatique
    seuil_haut = calculSeuilHaut(norme_gradient, centile);
    seuil_bas = seuil_haut / 2;

    // Étape 4 : Seuillage par hystérésis
    contours = seuillageHysteresis(non_maximums, angle_normale_gradient, seuil_haut, seuil_bas);
endfunction

// ========================
// 1) REHAUSSEMENT DE CANNY
// ========================

// Avant de chercher les contours de l'image, on commence par en réduire le bruit. Pour cela on applique un filtre gaussien
// Ceci permet d'éliminer les pixels isolés qui pourraient donner une forte intensité lors du calcul du gradient et donc de faux positifs
function image_filtre = appliquerFiltre(image, masque)
    // Prérequis 
    masque = normaliserMasque(masque);
    image = agrandirImage(image);

    [nb_lignes_image, nb_colonnes_image] = size(image); 

    // Cette fonction doit être générique et pouvoir appliquer n'importe quel filtre (pas forcément carré)
    [taille_x_masque, taille_y_masque] = size(masque); 
    demi_taille_masque_x = floor(taille_x_masque / 2);
    demi_taille_masque_y = floor(taille_y_masque / 2);

    // Faire le dessin pour bien comprendre les valeurs des index. On itère sur les pixels de l'image et non sur le cadre augmenté
    for i_image = 1 + demi_taille_masque_x : nb_lignes_image - demi_taille_masque_x
        for j_image = 1 + demi_taille_masque_y : nb_colonnes_image - demi_taille_masque_y
            somme = 0; // Pour chaque pixel, résultat (partiel) calculé lors de l'application du masque
            x2 = i_image - (demi_taille_masque_x + 1);
            y2 = j_image - (demi_taille_masque_y + 1);

            for x_masque = 1 : taille_x_masque 
                for y_masque = 1 : taille_y_masque
                    pixel_image = image(x2 + x_masque  , y2 + y_masque);
                    pixel_masque = masque(x_masque, y_masque);
                    somme = somme + (pixel_masque * pixel_image);
                end
            end
            // Le résultat est de la taille de l'image initiale (avant agrandissement), création à la volée
            image_filtre(i_image - demi_taille_masque_x, j_image - demi_taille_masque_y) = somme; 
        end
    end
endfunction

// Pour pouvoir appliquer un masque sur l'image, on doit pouvoir se placer sur des pixels se trouvant à côté de notre image de départ
function image_aggrandie = agrandirImage(image, masque)
    [nb_lignes_masque, nb_colonnes_masque] = size(masque);
    [nb_lignes_image, nb_colonnes_image] = size(image);

    demi_taille_masque_x = floor(nb_lignes_masque / 2); // Permet de savoir combien de pixels il faut agrandir le cadre de notre image originale sur chaque bord
    demi_taille_masque_y = floor(nb_colonnes_masque / 2); // On doit fonctionner, peu importe la taille du masque, donc il faut différencier les lignes et les colonnes

    // Création d'une nouvelle matrice (vide) de taille agrandie.
    nb_lignes_aggrandie = nb_lignes_image + 2 * demi_taille_masque_x; // On multiplie par 2 car on souhaite agrandir sur chaque extrémité
    nb_colonnes_aggrandie = nb_colonnes_image + 2 * demi_taille_masque_y;
    image_aggrandie = zeros(nb_lignes_aggrandie, nb_colonnes_aggrandie);

    // On replace maintenant notre image originale dans la nouvelle matrice en se décalant correctement par rapport à ce qu'on a agrandi. On veux l'image originale au centre
    for x = demi_taille_masque_x :(nb_lignes_aggrandie - demi_taille_masque_x)
        for y = demi_taille_masque_y :(nb_colonnes_aggrandie - demi_taille_masque_y)
            // On reprend les pixels de l'image initiale depuis le début
            x_image_origin = x - demi_taille_masque_x;
            y_image_origin = y - demi_taille_masque_y;
            if (x_image_origin > 0 & y_image_origin > 0) then // Les indices scilab commencent à 1 et non à 0
                image_aggrandie(x, y) = image(x_image_origin, y_image_origin);
            end
        end
    end
endfunction

// Calcul pour chaque pixel de l'image, la norme du gradient et l'angle de la normale au gradient
function [norme_gradient, angle_normale_gradient] = calculGradient(image_filtre)
    // Prérequis et initialisations
    masque_convolution_x = [1, 0, -1]; // Donné dans le cours
    masque_convolution_y = [1;0;-1]; 

    matrice_gradient_x = appliquerFiltre(image_filtre, masque_convolution_x); 
    matrice_gradient_y = appliquerFiltre(image_filtre, masque_convolution_y); 

    [nb_lignes_image, nb_colonnes_image] = size(image_filtre); 

    norme_gradient = zeros(nb_lignes_image, nb_colonnes_image); // Correspond à 'es'
    angle_normale_gradient = zeros(nb_lignes_image, nb_colonnes_image); // Correspond à 'eo'

    for x = 1 : nb_lignes_image
        for y = 1 : nb_colonnes_image
            Jx = matrice_gradient_x(x, y); // Gradient en x
            Jy = matrice_gradient_y(x, y); // Gradient en y
            norme_gradient(x, y) = sqrt(Jx**2 + Jy**2); // La norme du gradient correspond à son intensité
            angle_temp = atan(-Jy, Jx); // Résultat en radians, à convertir en degrés et à normaliser
            // L'angle de la normale au gradient nous donne la direction du contour. Il faut donc normaliser car on peut accéder à droite, gauche, diagonale... mais rien d'autre !
            angle_normale_gradient(x, y) = approxAngleNormaleGradient(angle_temp); 
        end
    end
endfunction

// On se ramène à des directions connues (ayant une valeur en degré) pour la direction des contours
function angle_degre_normalise = approxAngleNormaleGradient(angle_radian)
    angle_degre = radianEnDegre(angle_radian);
    if (angle_degre < 0) then
        angle_degre = angle_degre + 180; // Se ramener au demi-cercle trigo supérieure
    end
    // On veut maintenant n'avoir que des valeurs 0, 45, 90 ou 135°
    seuil_min_45 = 45 / 2;
    seuil_min_90 = (90 + 45) / 2;
    seuil_min_135 = (135 + 90) / 2;
    seuil_max_135 = (180 + 135) / 2;

    // On sait que valeur_degre > 0
    if angle_degre >= seuil_min_45 & angle_degre < seuil_min_90 then
        angle_degre_normalise = 45; // Diagonale
    elseif angle_degre >= seuil_min_90 & angle_degre < seuil_min_135 then
        angle_degre_normalise = 90; // Vertical
    elseif angle_degre >= seuil_min_135 & angle_degre < seuil_max_135  then
        angle_degre_normalise = 135; // Diagonale
    else
        angle_degre_normalise = 0; // Pour le cas de 180°, on reboucle sur 0 (horizontal)
    end
endfunction

// ==============================
// 2) SUPRESSION DES NON-MAXIMUMS
// ==============================

// Une forte intensité ne suffit pas à décider si un point correspond à un contour ou non car les contours ne sont souvent pas 'bruts' mais 'progressifs'
// Il faut que ces fortes intensités correspondent à des maximas locaux (pour ne pas avoir un contour trop épais)
function [non_maximums] = supprimerNonMaximums(norme_gradient, angle_normale_gradient)
    [nb_lignes, nb_colonnes] = size(norme_gradient);
    non_maximums = zeros(nb_lignes, nb_colonnes);

    for x = 1 : nb_lignes
        for y = 1 : nb_colonnes
            angle = angle_normale_gradient(x, y);
            [voisin1, voisin2] = recupererVoisins(angle, norme_gradient, x, y);
            if norme_gradient(x, y) < voisin1 | norme_gradient(x, y) < voisin2 then // Si plus petit qu'au moins un des deux voisins, on supprime
                non_maximums(x, y) = 0;
            else // sinon on conserve le contour
                non_maximums(x, y) = norme_gradient(x, y);
            end
        end       
    end
endfunction

// ===========================
// 3) SEUILLAGE PAR HYSTÉRÉSIS
// ===========================

// Les contours donnés par les fortes valeurs du gradient sont souvent étalés, voire flous. Le seuillage à hystérésis permet de les affiner et de ne conserver que les contours les plus cohérents.
// Un pixel de contour ne peut pas être un pixel isolé
function contours = seuillageHysteresis(non_maximums, angle_normale_gradient, seuil_haut, seuil_bas)
    // seuil haut = th et seuil bas = tl
    assert_checktrue(seuil_haut > seuil_bas);

    // On veut une image finale composée uniquement de blanc et de noir
    blanc = 255;
    noir = 0;

    [nb_lignes, nb_colonnes] = size(angle_normale_gradient); 
    contours = non_maximums;
    // Premier passage sur l'image, on garde tous les pixels dont la norme du gradient (intensité) est supérieure au seuil haut
    for i = 1:nb_lignes
        for j = 1:nb_colonnes
            if non_maximums(i,j) > seuil_haut then
                contours(i,j) = blanc; 
            elseif non_maximums(i,j) < seuil_bas
                contours(i,j) = noir; 
            end 
        end
    end

    // Deuxième passage sur l'image résultante, on regarde si les pixels dont l'intensité du gradient est comprise entre les deux seuils et on accepte si le pixel est relié à un autre pixel déjà compté comme contour
    // Doit être faire dans un second passage sur l'image car on regarde les voisins, qui pourrait ne pas encore avoir été traité (en dessous, à droite...). Cependant on augmente la complexité de l'algorithme
    for i = 1:nb_lignes
        for j = 1:nb_colonnes
            if non_maximums(i,j) >= seuil_bas & non_maximums(i,j) <= seuil_haut then 
                angle = angle_normale_gradient(i,j) + 90; // Perpendiculaire à la normale du gradient
                if angle >= 180 then
                    angle = angle - 180;
                end

                [voisin1, voisin2] = recupererVoisins(angle, non_maximums, i, j); // Récupère les voisins perpendiculairement à la normale
                if voisin1 > seuil_haut & voisin2 > seuil_haut then // Si les voisins sont acceptés comme contours, leur valeur est supérieur au seuil haut
                    contours(i,j) = blanc;
                else
                    contours(i,j) = noir;
                end
            end
        end
    end
    // Les pixels inférieurs au seuil bas sont déjà rejetés puisque la matrice 'contours' est initialisée en noir (0)
endfunction

// ========================
// DETERMINATION DES SEUILS
// ========================

// Récupère la valeur du centile demandé à partir de la fonction de répartition de l'histogramme de la norme des gradients
function seuil_haut = calculSeuilHaut(norme_gradient, centile)
    [histogramme, pas] = calculHistogramme(norme_gradient);
    fonctionRepartition = calculFonctionRepartition(histogramme);

    nombre_pixels = length(norme_gradient);
    pivot = nombre_pixels * centile; // Pixel à partir duquel tous les pixels sont au-dessus ou au-dessous du centile voulu

    seuil_haut_index = 1;
    // Détermination du seuil haut
    for i = 1 : length(fonctionRepartition)
        if ((pivot - fonctionRepartition(seuil_haut_index)) > (pivot - fonctionRepartition(i))) & (pivot - fonctionRepartition(i) > 0) then
            seuil_haut_index = i; // Position du seuil haut dans la fonction de répartition
        end
    end
    seuil_haut = pas * (seuil_haut_index - 1); // -1 car le pas avait été incrémenté de 1 dans le calcul de l'histogramme

    // Validation du calcul de seuil haut
    compare = perctl(norme_gradient, centile * 100);
endfunction

function [histogramme, pas] = calculHistogramme(norme_gradient)
    // L'histogramme représente la distribution des intensités de l'image
    [nb_lignes, nb_colonnes] = size(norme_gradient);

    norme_max = max(norme_gradient);
    norme_min = min(norme_gradient);
    ecart_min_max = norme_max - norme_min;

    nb_pas = 1000; // Précision de l'histogramme
    pas = ecart_min_max / (nb_pas - 1);

    histogramme = zeros(1, nb_pas);

    // On parcourt chaque pixel de l'image et on place sa valeur au bon endroit dans l'histogramme
    for i = 1 : nb_lignes
        for j = 1 : nb_colonnes
            // Le pixel est forcément entre norme_min et norme_max
            valeur_pixel = norme_gradient(i,j);
            position = floor((valeur_pixel - norme_min) / pas ) + 1;// position du pixel dans l'histogramme. La division ne rend pas forcément un résultat entier. Décalage par rapport à 0
            histogramme(1, position) = histogramme(1, position) + 1;
        end
    end
    //  plot(histogramme);
endfunction

// Représente le nombre de pixels inférieur ou égal au pas calculé dans l'histogramme
function fonctionRepartition = calculFonctionRepartition(histogramme)
    nb_pas = length(histogramme);
    fonctionRepartition = zeros(1, nb_pas);
    fonctionRepartition(1) = histogramme(1); // Initialisation
    for i = 2 : nb_pas
        fonctionRepartition(i) = fonctionRepartition(i - 1) + histogramme(i - 1);
    end
    //plot(fonctionRepartition);
endfunction

// =====================
// FONCTIONS UTILITAIRES
// =====================

// Récupère les pixels adjacents en fonction de la direction du gradient
function [voisin1, voisin2] = recupererVoisins(angle, norme_gradient, x, y)
    select angle // En fonction de la valeur de l'angle on récupère des voisins différents
    case 0 then
        voisin1 = recupererValeurPixel(norme_gradient, x , y - 1);
        voisin2 = recupererValeurPixel(norme_gradient, x , y + 1);
    case 45 then
        voisin1 = recupererValeurPixel(norme_gradient, x - 1, y + 1);
        voisin2 = recupererValeurPixel(norme_gradient, x + 1, y - 1);
    case 90 then
        voisin1 = recupererValeurPixel(norme_gradient, x - 1, y);
        voisin2 = recupererValeurPixel(norme_gradient, x + 1, y);
    case 135 then
        voisin1 = recupererValeurPixel(norme_gradient, x - 1, y - 1);
        voisin2 = recupererValeurPixel(norme_gradient, x + 1, y + 1);
    end
    // On a fait une normalisation de l'angle, il n'y a pas d'autres valeurs possible que ces 4-là. 
endfunction

// Retourne la norme d'un pixel ou 0 si le pixel est en dehors de la matrice
function norme = recupererValeurPixel(matrice, x, y)
    [nb_lignes, nb_colonnes] = size(norme_gradient);
    if x > 0 & x <= nb_lignes & y > 0 & y <= nb_colonnes then 
        norme = norme_gradient(x, y); 
    else
        norme = 0 ;
    end
endfunction

function degre = radianEnDegre(radian)
    degre = 180 * radian / %pi;
endfunction

// On divise par la somme des pixels du masque pour ne pas modifier la valeur moyenne de l'image lors de l'application d'un masque
function masque = normaliserMasque(masque)
    if sum(masque) <> 0 then // On s'assure de ne pas tenter une division par 0 (cas des masques de convolutions pour le calcul des gradients par exemple)
        masque = (1 / sum(masque)). * masque; 
    end
endfunction

function matrice_image = chargerImage(path, isRGB)
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

clc;
main
