
#%%
import geopandas as gpd
import pandas as pd
import numpy as np

from shapely.geometry import Point, LineString
import pandas as pd
import geopandas as gp
from shapely.geometry import Point, Polygon
from math import radians, cos, sin, asin, sqrt
#%%
def match_hholds_to_zone(year, point_buffer, dist_size): 

    print(f'Processing for year {year}...')

    def haversine(lon1, lat1, lon2, lat2):
        """Calculate the haversine distance between two locations"""
        lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
        # haversine formula 
        dlon = lon2 - lon1 
        dlat = lat2 - lat1 
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a)) 
        r = 6371 # radius of earth in kilometers, use 3956 for miles
        return c * r

    # data
    xq = pd.read_stata('./inter/school_assignment.dta')
    hh = pd.read_stata('./inter/transaction.dta')
    if (year == 2013) | (year == 2014):
        xq = xq[(xq['year'] == 2015) & (xq['key'] == 1)]
    elif year == 2017:
        xq = xq[(xq['year'] == year + 1) & (xq['key'] == 1)]
    else: 
        xq = xq[(xq['year'] == year) & (xq['key'] == 1)]

    hh = hh[(hh['n_lat'].notnull()) & (hh['year'] == year)]

    # create school attendance zones 
    count = 0
    SAZ_df = gpd.GeoDataFrame()

    for i in xq['schoolname'].unique():
        count = count + 1
        print(f'{i}')
        xq_i = xq[xq['schoolname'] == f'{i}']
        xq_i['geometry'] = gpd.points_from_xy(xq_i.longitude, xq_i.latitude, crs ="EPSG:4326")
        xqgdf = gpd.GeoDataFrame(xq_i, geometry = 'geometry')
        if point_buffer != 0 :
            xqgdf.buffer(point_buffer)
        # get rid of outliers 
        xqgdf['mlat'] = np.median(xqgdf.latitude)
        xqgdf['mlon'] = np.median(xqgdf.longitude)
        xqgdf['dist'] = xqgdf.apply(lambda row: haversine(row['longitude'], 
                                                        row['latitude'], 
                                                        row['mlon'], 
                                                        row['mlat']), axis=1)
        xqgdf = xqgdf[xqgdf['dist'] < dist_size]
        xqgdf = xqgdf.dissolve(by = 'schoolname')

        # draw a convex hull
        convex = xqgdf.convex_hull.reset_index().set_geometry(0)
        convex_df = gpd.GeoDataFrame(convex, geometry = 0)
        convex_df['SAZ_id'] = count
        SAZ_df = SAZ_df.append(convex_df)

    # record the boundary & set a buffer for BDD
    bound = pd.DataFrame()
    for i in SAZ_df['SAZ_id'].unique():
        bound_i = pd.DataFrame()
        bound_i['geometry_bound'] = SAZ_df[SAZ_df['SAZ_id'] == i].boundary
        bound_i['bound_id'] = i
        bound = bound.append(bound_i)

    # households within zones
    hh['geometry'] = gpd.points_from_xy(hh.n_lon, hh.n_lat, crs ="EPSG:4326")
    hhgdf = gpd.GeoDataFrame(hh, geometry = 'geometry')
    hhgdf = hhgdf[hhgdf['geometry'].notnull()]
    matched = gpd.sjoin(hhgdf, SAZ_df, how = 'left', op = 'intersects')
    matched = matched.drop(columns = ['index_right'])
    matched = matched.drop_duplicates(subset = ['transaction_id'])
    # separate treatment and control
    treatment = matched[matched['SAZ_id'].notnull()]
    control = matched[matched['SAZ_id'].isnull()]

    # for treatment group, calculate their distance to the respective boundary 
    treatment = pd.merge(treatment, bound, left_on = 'SAZ_id', right_on = 'bound_id', how = 'left')
    treatment['distance'] = treatment.apply(lambda row: row['geometry'].distance(row['geometry_bound']), axis=1)

    # for control group, calculate their distance to all the boundaries, and take the closest 
    # join control group with boundary
    bound['merge'] = 1
    joined_df = control[['transaction_id', 'geometry']]
    joined_df['merge'] = 1
    joined_df = pd.merge(joined_df, bound, on = 'merge', how = 'inner')
    joined_df['distance'] = joined_df.apply(lambda row: row['geometry'].distance(row['geometry_bound']), axis=1)

    joined_df_min = joined_df.groupby(by = ['transaction_id'])['distance'].min().reset_index()
    joined_df_min = pd.merge(joined_df_min, joined_df[['transaction_id', 'bound_id', 'distance']], on = ['transaction_id', 'distance'], how = 'left')
    joined_df_min = joined_df_min.drop_duplicates(subset = 'transaction_id')
    control = pd.merge(control, joined_df_min, on = 'transaction_id', how = 'left')

    final = treatment.append(control)
    final = final.drop(columns = ['geometry', 'geometry_bound'])
    final.to_csv(f'./inter/temp/{year}_{point_buffer}_{dist_size}.csv', index = False, encoding = 'utf-8')

#%%
# year, ring, point_buffer, dist_size
for i in [2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021]:
    match_hholds_to_zone(i, 0, 3)

print('DONE!')
# %%
